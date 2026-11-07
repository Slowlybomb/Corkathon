import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

function disposeObject(root) {
  const resources = new Set(),
    images = new Set();
  root.traverse(object => {
    if (object.geometry) resources.add(object.geometry);
    if (object.skeleton) resources.add(object.skeleton);
    for (const material of object.material
      ? Array.isArray(object.material)
        ? object.material
        : [object.material]
      : []) {
      resources.add(material);
      for (const value of Object.values(material))
        if (value?.isTexture) {
          resources.add(value);
          if (value.source?.data?.close) images.add(value.source.data);
        }
    }
  });
  resources.forEach(resource => resource.dispose());
  images.forEach(image => image.close());
}

// One upright, assembled model convention for both the geographic map and attitude view.
export async function loadDroneModel(span = 140) {
  const gltf = await new GLTFLoader().loadAsync(new URL('./assets/drone/drone.glb', import.meta.url).href);
  const model = new THREE.Group();
  model.name = 'drone-model';
  model.rotation.x = Math.PI / 2;
  model.add(gltf.scene);
  const mixer = new THREE.AnimationMixer(gltf.scene),
    hover = gltf.animations.find(clip => clip.name === 'hover');
  if (hover) {
    mixer.clipAction(hover).play();
    mixer.setTime(0);
  }
  const dispose = () => {
    mixer.stopAllAction();
    mixer.uncacheRoot(gltf.scene);
    disposeObject(model);
  };
  model.updateMatrixWorld(true);
  const bounds = new THREE.Box3().setFromObject(model, true),
    size = bounds.getSize(new THREE.Vector3());
  const originalSpan = Math.max(size.x, size.y);
  if (!Number.isFinite(originalSpan) || originalSpan <= 0) {
    dispose();
    throw new Error('Drone model has invalid dimensions');
  }
  const scale = span / originalSpan;
  model.scale.setScalar(scale);
  model.position.copy(bounds.getCenter(new THREE.Vector3())).multiplyScalar(-scale);
  return { model, mixer, dispose };
}
