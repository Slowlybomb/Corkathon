package ie.corkathon.phone;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.*;
import android.util.Base64;
import android.view.View;
import android.view.WindowManager;
import android.widget.*;
import org.json.*;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.text.SimpleDateFormat;
import java.util.*;

/** Foreground demonstration app. Model execution belongs to the AI teammate. */
public final class MainActivity extends Activity {
    static final UUID SERVICE = UUID.fromString("aa7a0001-7f6b-4c80-9f55-477f39b00001");
    static final UUID RX = UUID.fromString("aa7a0002-7f6b-4c80-9f55-477f39b00001");
    static final UUID TX = UUID.fromString("aa7a0003-7f6b-4c80-9f55-477f39b00001");
    static final UUID CCC = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private final Handler main = new Handler(Looper.getMainLooper());
    private final PacketBuffer incoming = new PacketBuffer(1024);
    private final ArrayDeque<byte[]> outgoing = new ArrayDeque<>();
    private final ArrayDeque<String> logs = new ArrayDeque<>();
    private BluetoothAdapter adapter;
    private BluetoothGattServer server;
    private BluetoothGattCharacteristic transmit;
    private BluetoothDevice peer;
    private SnapshotCamera camera;
    private PhoneTelemetry telemetry;
    private TextView status, code, cameraStatus, telemetryStatus, logView;
    private ScrollView logScroll;
    private Switch armed, limited, shareSensors;
    private Button start, stop, test;
    private boolean running, subscribed, authenticated, sending, visible;
    private int offset, inFlight, chunkSize = 20, session;
    private String pin = "", captureId;
    private byte[] imageTransfer;
    private final Runnable telemetryTick = new Runnable() {
        @Override public void run() { if (visible) { publishTelemetry(); main.postDelayed(this, limited.isChecked()?1000:200); } }
    };
    private static final int CREAM = Color.rgb(254,254,227), MUTED = Color.rgb(184,202,181), INK = Color.rgb(16,44,32);

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(INK); getWindow().setNavigationBarColor(INK);
        camera = new SnapshotCamera(this, main);
        telemetry = new PhoneTelemetry(this, main);
        adapter = getSystemService(BluetoothManager.class).getAdapter();
        LinearLayout root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20),dp(20),dp(20),dp(12)); root.setBackgroundColor(INK);
        setContentView(root);
        text(root,"Ithir Camera Module",24,CREAM).setTypeface(null,Typeface.BOLD);
        text(root,"Camera module · stationary capture",14,MUTED);
        status=text(root,"Bluetooth stopped",18,CREAM);
        code=text(root,"Start Bluetooth to get a connection code",15,MUTED);
        LinearLayout controls=new LinearLayout(this);root.addView(controls);
        start=button(controls,"Start Bluetooth",this::startBluetooth);
        stop=button(controls,"Stop",this::stopBluetooth);stop.setEnabled(false);
        armed=new Switch(this);armed.setText("Allow camera requests");armed.setTextColor(CREAM);armed.setMinHeight(dp(48));root.addView(armed);
        armed.setOnCheckedChangeListener((view,enabled)->{
            if(enabled&&checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED){armed.setChecked(false);requestPermissions(new String[]{Manifest.permission.CAMERA},2);return;}
            if(!enabled)cancelCapture("Camera disarmed");
            updateCamera();if(authenticated)sendStatus();
        });
        cameraStatus=text(root,"Camera off · requests blocked",14,MUTED);
        shareSensors=new Switch(this);shareSensors.setText("Share GPS and orientation");shareSensors.setTextColor(CREAM);shareSensors.setMinHeight(dp(48));root.addView(shareSensors);
        telemetryStatus=text(root,"Sensors off",13,MUTED);
        shareSensors.setOnCheckedChangeListener((view,enabled)->{
            if(enabled){
                getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);telemetry.start();
                if(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED)
                    requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION},3);
            }else{telemetry.stop();getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);}
            publishTelemetry();
        });
        limited=new Switch(this);limited.setText("Limit link to 1 kbit/s (simulation)");limited.setTextColor(CREAM);limited.setMinHeight(dp(48));root.addView(limited);
        limited.setOnCheckedChangeListener((view,enabled)->{log(enabled?"Simulated 1 kbit/s limit enabled":"Bluetooth speed; no LoRa simulation");if(authenticated)sendStatus();});
        text(root,"Model on this phone: Century ARM64",16,CREAM);
        button(root,"Open model test",()->startActivity(new android.content.Intent(this,ModelTestActivity.class)));
        test=button(root,"Send connection test",()->send(packet("log","message","Manual connection test; no model result")));test.setEnabled(false);
        LinearLayout logHeading=new LinearLayout(this);logHeading.setGravity(android.view.Gravity.CENTER_VERTICAL);root.addView(logHeading);
        TextView title=text(logHeading,"Activity log",17,CREAM);title.setLayoutParams(new LinearLayout.LayoutParams(0,dp(48),1));title.setGravity(android.view.Gravity.CENTER_VERTICAL);
        button(logHeading,"Clear",()->{logs.clear();logView.setText("");});
        logScroll=new ScrollView(this);root.addView(logScroll,new LinearLayout.LayoutParams(-1,0,1));
        logView=new TextView(this);logView.setTextColor(MUTED);logView.setTextSize(13);logView.setTextIsSelectable(true);logView.setLineSpacing(dp(4),1);logScroll.addView(logView);
        text(root,"Keep this app visible. Leaving it stops Bluetooth and capture.",12,MUTED);
        log("Ready. Camera and model are idle.");
    }
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private TextView text(LinearLayout parent,String value,int size,int color){TextView view=new TextView(this);view.setText(value);view.setTextSize(size);view.setTextColor(color);view.setPadding(0,dp(5),0,dp(5));parent.addView(view);return view;}
    private Button button(LinearLayout parent,String label,Runnable action){Button button=new Button(this);button.setText(label);button.setAllCaps(false);button.setTextColor(INK);button.setBackgroundTintList(ColorStateList.valueOf(CREAM));button.setMinHeight(dp(48));button.setOnClickListener(view->action.run());parent.addView(button);return button;}
    private void log(String message){
        if(Looper.myLooper()!=Looper.getMainLooper()){main.post(()->log(message));return;}
        logs.addLast(new SimpleDateFormat("HH:mm:ss",Locale.UK).format(new Date())+"  "+message);
        while(logs.size()>150)logs.removeFirst();logView.setText(String.join("\n",logs));logScroll.post(()->logScroll.fullScroll(View.FOCUS_DOWN));
    }
    private JSONObject packet(String type,Object... fields){
        JSONObject value=new JSONObject();try{value.put("v",1);value.put("type",type);value.put("sentAt",System.currentTimeMillis());for(int i=0;i<fields.length;i+=2)value.put((String)fields[i],fields[i+1]);}catch(JSONException exception){throw new IllegalArgumentException(exception);}return value;
    }
    private void startBluetooth(){
        if(running)return;
        if(Build.VERSION.SDK_INT>=31&&(checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED||checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE)!=PackageManager.PERMISSION_GRANTED)){
            requestPermissions(new String[]{Manifest.permission.BLUETOOTH_CONNECT,Manifest.permission.BLUETOOTH_ADVERTISE},1);return;
        }
        if(adapter==null){log("Bluetooth is unavailable on this device");return;}
        if(!adapter.isEnabled()){startActivity(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE));log("Enable Bluetooth, then tap Start Bluetooth again");return;}
        if(adapter.getBluetoothLeAdvertiser()==null){log("This device does not support BLE advertising");return;}
        try{
            pin=String.format(Locale.ROOT,"%06d",new SecureRandom().nextInt(1000000));
            server=getSystemService(BluetoothManager.class).openGattServer(this,callbacks);
            if(server==null)throw new IllegalStateException("Could not open Bluetooth server");
            BluetoothGattService service=new BluetoothGattService(SERVICE,BluetoothGattService.SERVICE_TYPE_PRIMARY);
            service.addCharacteristic(new BluetoothGattCharacteristic(RX,BluetoothGattCharacteristic.PROPERTY_WRITE,BluetoothGattCharacteristic.PERMISSION_WRITE));
            transmit=new BluetoothGattCharacteristic(TX,BluetoothGattCharacteristic.PROPERTY_NOTIFY,0);
            transmit.addDescriptor(new BluetoothGattDescriptor(CCC,BluetoothGattDescriptor.PERMISSION_READ|BluetoothGattDescriptor.PERMISSION_WRITE));service.addCharacteristic(transmit);
            running=true;start.setEnabled(false);stop.setEnabled(true);
            if(!server.addService(service))throw new IllegalStateException("Could not register BLE service");
            code.setText("Connection code: "+pin);status.setText("Starting Bluetooth…");
        }catch(Exception exception){log("Bluetooth start failed: "+exception.getMessage());stopBluetooth();}
    }
    private void advertise(){
        if(!running||!visible)return;
        try{adapter.getBluetoothLeAdvertiser().startAdvertising(new AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER).setConnectable(true).setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM).build(),new AdvertiseData.Builder().addServiceUuid(new ParcelUuid(SERVICE)).build(),advertising);}
        catch(Exception exception){log("Advertising failed: "+exception.getMessage());stopBluetooth();}
    }
    private final AdvertiseCallback advertising=new AdvertiseCallback(){
        @Override public void onStartSuccess(AdvertiseSettings settings){main.post(()->{if(running){status.setText("Waiting for ground station");log("BLE service visible. Enter the camera module's code in the dashboard.");}});}
        @Override public void onStartFailure(int error){main.post(()->{log("BLE advertising failed: "+error);stopBluetooth();});}
    };
    private void clearPeer(){
        session++;authenticated=false;subscribed=false;peer=null;incoming.reset();outgoing.clear();imageTransfer=null;offset=0;sending=false;test.setEnabled(false);cancelCapture("Link closed");
    }
    private void stopBluetooth(){
        running=false;
        try{if(adapter!=null&&adapter.isEnabled()&&adapter.getBluetoothLeAdvertiser()!=null)adapter.getBluetoothLeAdvertiser().stopAdvertising(advertising);}catch(SecurityException ignored){}
        if(server!=null){try{server.close();}catch(SecurityException ignored){}finally{server=null;}}clearPeer();
        start.setEnabled(true);stop.setEnabled(false);status.setText("Bluetooth stopped");code.setText("Start Bluetooth to get a connection code");log("Bluetooth stopped; camera released");
    }
    private final BluetoothGattServerCallback callbacks=new BluetoothGattServerCallback(){
        @Override public void onServiceAdded(int result,BluetoothGattService service){main.post(()->{if(!running)return;if(result==BluetoothGatt.GATT_SUCCESS)advertise();else{log("BLE service registration failed: "+result);stopBluetooth();}});}
        @Override public void onConnectionStateChange(BluetoothDevice device,int result,int state){main.post(()->{
            if(!running||server==null)return;
            if(Build.VERSION.SDK_INT>=31&&(checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED||checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE)!=PackageManager.PERMISSION_GRANTED)){stopBluetooth();return;}
            if(state==BluetoothProfile.STATE_CONNECTED){
                if(peer!=null&&!peer.equals(device)){server.cancelConnection(device);return;}
                clearPeer();peer=device;chunkSize=20;adapter.getBluetoothLeAdvertiser().stopAdvertising(advertising);status.setText("Connected · waiting for code");log("Ground station connected; authentication required");
                int current=session;main.postDelayed(()->{
                    if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){stopBluetooth();return;}
                    if(current==session&&peer!=null&&!authenticated){log("Authentication timed out");server.cancelConnection(peer);}
                },15000);
            }else if(state==BluetoothProfile.STATE_DISCONNECTED&&device.equals(peer)){clearPeer();status.setText("Waiting for ground station");log("Ground station disconnected");advertise();}
        });}
        @Override public void onMtuChanged(BluetoothDevice device,int mtu){main.post(()->{if(device.equals(peer))chunkSize=Math.max(20,Math.min(180,mtu-3));});}
        @Override public void onCharacteristicWriteRequest(BluetoothDevice device,int requestId,BluetoothGattCharacteristic characteristic,boolean prepared,boolean response,int startOffset,byte[] value){main.post(()->{
            if(server==null)return;
            if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){stopBluetooth();return;}
            boolean valid=device.equals(peer)&&RX.equals(characteristic.getUuid())&&!prepared&&startOffset==0;
            if(response)server.sendResponse(device,requestId,valid?BluetoothGatt.GATT_SUCCESS:BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,0,null);
            if(valid)try{incoming.accept(value,MainActivity.this::command);}catch(IllegalArgumentException exception){log(exception.getMessage());server.cancelConnection(device);}
        });}
        @Override public void onDescriptorWriteRequest(BluetoothDevice device,int requestId,BluetoothGattDescriptor descriptor,boolean prepared,boolean response,int startOffset,byte[] value){main.post(()->{
            if(server==null)return;
            if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){stopBluetooth();return;}
            boolean valid=device.equals(peer)&&CCC.equals(descriptor.getUuid())&&!prepared&&startOffset==0&&(Arrays.equals(value,BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)||Arrays.equals(value,BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE));
            if(valid){subscribed=Arrays.equals(value,BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);if(!subscribed)cancelCapture("Notifications disabled");}
            if(response)server.sendResponse(device,requestId,valid?BluetoothGatt.GATT_SUCCESS:BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,0,null);
        });}
        @Override public void onDescriptorReadRequest(BluetoothDevice device,int requestId,int startOffset,BluetoothGattDescriptor descriptor){main.post(()->{
            if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){stopBluetooth();return;}
            if(server!=null)server.sendResponse(device,requestId,startOffset==0?BluetoothGatt.GATT_SUCCESS:BluetoothGatt.GATT_INVALID_OFFSET,0,subscribed?BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE:BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE);
        });}
        @Override public void onNotificationSent(BluetoothDevice device,int result){main.post(()->{
            if(!device.equals(peer)||!sending)return;
            if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){stopBluetooth();return;}
            if(result!=BluetoothGatt.GATT_SUCCESS){log("Bluetooth transfer failed; reconnect the dashboard");server.cancelConnection(device);return;}
            offset+=inFlight;int delay=limited.isChecked()?inFlight*8:0;
            if(!outgoing.isEmpty()&&offset>=outgoing.peek().length){if(outgoing.remove()==imageTransfer)imageTransfer=null;offset=0;}
            int current=session;main.postDelayed(()->{if(current==session){sending=false;flush();}},delay);
        });}
    };
    private void send(JSONObject packet){
        if(!subscribed||peer==null)return;
        byte[] bytes=(packet.toString()+"\n").getBytes(StandardCharsets.UTF_8);
        if(bytes.length>65536||outgoing.size()>=8){log("Packet queue full or oversized; packet rejected");return;}
        if("image".equals(packet.optString("type")))imageTransfer=bytes;
        outgoing.add(bytes);flush();
    }
    private void flush(){
        if(sending||outgoing.isEmpty()||!subscribed||peer==null||server==null)return;
        if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){stopBluetooth();return;}
        byte[] frame=outgoing.peek();inFlight=Math.min(chunkSize,frame.length-offset);byte[] bytes=Arrays.copyOfRange(frame,offset,offset+inFlight);sending=true;
        boolean accepted;
        if(Build.VERSION.SDK_INT>=33)accepted=server.notifyCharacteristicChanged(peer,transmit,false,bytes)==BluetoothStatusCodes.SUCCESS;
        else{transmit.setValue(bytes);accepted=server.notifyCharacteristicChanged(peer,transmit,false);}
        if(!accepted){sending=false;log("Notification rejected; reconnect the dashboard");server.cancelConnection(peer);}
    }
    private void command(String wire){
        if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){stopBluetooth();return;}
        try{
            JSONObject value=new JSONObject(wire);String name=value.optString("command"),id=value.optString("id");
            if(value.optInt("v")!=1||!"command".equals(value.optString("type")))throw new IllegalArgumentException("Unsupported packet version or type");
            if(!authenticated){
                if(!"hello".equals(name)||!pin.equals(value.optString("pin"))||!subscribed){log("Connection code rejected");server.cancelConnection(peer);return;}
                authenticated=true;test.setEnabled(true);status.setText("Ground station connected");log("Connection code accepted");send(packet("ready","model","not_connected"));sendStatus();return;
            }
            log("Received: "+name);
            switch(name){
                case "ping": send(packet("pong","id",id));sendStatus();break;
                case "capture":
                    if(!armed.isChecked()){send(packet("error","id",id,"message","Allow camera requests on the camera module first"));break;}
                    if(camera.active||captureId!=null||imageTransfer!=null){send(packet("error","id",id,"message","Camera module busy; wait for the current transfer"));break;}
                    captureId=id;send(packet("ack","id",id,"command",name));
                    camera.capture(jpeg->{String completed=captureId;captureId=null;updateCamera();log("Captured "+jpeg.length+" bytes; camera off; sending image");send(packet("image","id",completed,"capturedAt",System.currentTimeMillis(),"location",telemetry.snapshot().opt("location"),"mime","image/jpeg","base64",Base64.encodeToString(jpeg,Base64.NO_WRAP)));sendStatus();},message->{captureId=null;updateCamera();log(message);send(packet("error","id",id,"message",message));sendStatus();});
                    updateCamera();break;
                case "stop_camera":cancelCapture("Stopped from dashboard");sendStatus();break;
                default:send(packet("error","id",id,"message","Unsupported command"));
            }
        }catch(Exception exception){log("Rejected command: "+exception.getMessage());send(packet("error","message","Invalid command packet"));}
    }
    private void cancelCapture(String reason){String cancelled=captureId;captureId=null;camera.stop();updateCamera();if(cancelled!=null){log(reason);send(packet("error","id",cancelled,"message",reason));}}
    private void updateCamera(){cameraStatus.setText(camera.active?"Capturing one image…":armed.isChecked()?"Camera off · requests allowed":"Camera off · requests blocked");}
    private void sendStatus(){
        BatteryManager battery=getSystemService(BatteryManager.class);int percent=battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
        send(packet("status","camera",camera.active?"capturing":"off","armed",armed.isChecked(),"model","not_connected","battery",percent>=0&&percent<=100?percent:JSONObject.NULL,"simulatedBps",limited.isChecked()?1000:JSONObject.NULL));
    }
    private void publishTelemetry(){
        JSONObject reading=telemetry.snapshot();
        JSONObject position=reading.optJSONObject("location"),attitude=reading.optJSONObject("orientation");
        String gps=position==null?reading.optString("gpsState").replace('_',' '):String.format(Locale.UK,"%.6f, %.6f · ±%.0f m",position.optDouble("latitude"),position.optDouble("longitude"),position.optDouble("accuracyM"));
        String heading=attitude==null?reading.optString("orientationState"):String.format(Locale.UK,"%.0f° %s · pitch %.0f° · roll %.0f°",attitude.optDouble("headingDeg"),attitude.isNull("declinationDeg")?"magnetic":"true",attitude.optDouble("pitchDeg"),attitude.optDouble("rollDeg"));
        telemetryStatus.setText("GPS: "+gps+"\nOrientation: "+heading);
        // One current sample only. Image transfers take priority; never build a stale telemetry queue.
        if(authenticated&&outgoing.isEmpty()&&!sending&&captureId==null)
            send(packet("telemetry","location",reading.opt("location"),"orientation",reading.opt("orientation"),"gpsState",reading.opt("gpsState"),"orientationState",reading.opt("orientationState")));
    }
    /** Integration handoff only: call with the AI teammate's agreed observations. No model runs here. */
    public void publishObservations(JSONArray observations,long capturedAt){main.post(()->{if(authenticated)send(packet("observations","capturedAt",capturedAt,"observations",observations));else log("Observations not sent: ground station disconnected");});}
    @Override public void onRequestPermissionsResult(int request,String[] permissions,int[] results){super.onRequestPermissionsResult(request,permissions,results);if(request==3){if(visible&&shareSensors.isChecked()){telemetry.start();publishTelemetry();}if(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED)log("GPS needs precise location permission. Orientation can still work.");return;}boolean granted=results.length>0;for(int result:results)granted&=result==PackageManager.PERMISSION_GRANTED;if(!granted){log("Permission denied. Allow it in Android settings to use this feature.");return;}if(request==1&&visible)startBluetooth();if(request==2&&visible)armed.setChecked(true);}
    @Override protected void onResume(){super.onResume();visible=true;main.removeCallbacks(telemetryTick);main.post(telemetryTick);}
    @Override protected void onStop(){visible=false;main.removeCallbacks(telemetryTick);shareSensors.setChecked(false);telemetry.stop();stopBluetooth();super.onStop();}
    @Override protected void onDestroy(){camera.stop();telemetry.stop();main.removeCallbacksAndMessages(null);super.onDestroy();}
}
