# Corkathon project plan

Working project name: Corkathon. Updated 7 November 2026.

This is a product and hackathon delivery plan, not a technical specification. Confirmed decisions are separated from proposals and open questions.

## 1. Confirmed context

| Item | Confirmed information |
| --- | --- |
| Event | Cork Hackathon, UCC Computer Science Society |
| Deadline | 19:00 on 7 November 2026, Cork local time |
| Team | Three people: one strong technical contributor, one strong social contributor, and the project owner as a generalist |
| Analysis and dataset ownership | A teammate will choose what to analyse and find the dataset; search is underway. Which teammate holds this role has not been specified |
| Inspiration | OneSoil-style field monitoring and a central dashboard |
| Hardware | Custom 5-inch FPV drone and Realme phone, model RMX3363 |
| Intended phone role | Camera and computing unit for analysing observations during a future survey |
| Product ambition | Show drone position and analyse soil/vegetation coverage, unusual patches, possible wet areas, and soil properties |
| Hackathon flight | No flight. Demonstrate the physical construction |
| Current stage | Agree on the product, scope, and story; discuss technical implementation later |

The phone's attachment, payload suitability, and ability to perform the intended processing remain unverified. The static construction does not establish flight readiness.

## 2. Challenge and project response

The supplied challenge slide says:

> Your challenge: take data that exists today and turn it into something a busy person can act on.

It highlights three problems: timing matters, data is scattered, and users are not technical. Source: the organiser's slide supplied by the project owner, `2026-11-07 10.43.58.jpg`.

Our proposed response is a field inspection assistant. It brings observations into one panel, shows when they were captured, and helps a farmer choose where to inspect next.

| Challenge theme | Product response |
| --- | --- |
| Timing | Display capture time and age of observations; distinguish a fresh survey from older evidence |
| Scattered data | Connect a field map, imagery, observations, and available field records in one place |
| Nontechnical users | Lead with an inspection list and plain-language explanations; allow the user to open the evidence |
| Existing data | Demonstrate with an identified, reusable set of existing images or footage and any available field records; establish the actual sources before building |

The proposed drone-phone unit supplies a future source of fresh observations. For this hackathon, existing data and an honest replay should carry the demonstration. Confirm whether the organisers have additional requirements about eligible data sources.

## 3. Product concept and value

**Working pitch:** A drone-and-phone field scouting concept that turns field imagery into a map of places worth inspecting, with a simple dashboard showing the evidence and its age.

The proposed first user is a farmer or field manager deciding where to spend limited inspection time. This audience is an assumption to confirm through short conversations.

The proposed benefit is quicker prioritisation of field visits. Do not claim proven yield improvements, input savings, or agronomic accuracy without evidence.

OneSoil is a reference for the field-monitoring workflow. Our project focuses on the proposed phone-on-drone observation source and the inspection decision. This is a positioning hypothesis, not a claim of market uniqueness. See [OneSoil's platform overview](https://onesoil.ai/en/platform) for the inspiration.

## 4. Analysis vision

The project owner wants all four areas included. They belong in the product vision; the depth demonstrated for each depends on available evidence and time.

A teammate owns selecting the initial analysis target and dataset. This decision is pending their investigation; no specific soil property or dataset is committed yet.

| Area | Useful output | Evidence boundary for the demo |
| --- | --- | --- |
| Soil and vegetation coverage | Indicate visible bare soil and vegetation in sampled views | Show the source image and sampled area; do not present sampled coverage as a whole-field measurement |
| Unusual patches | Highlight visible differences for a person to inspect | Describe the observed difference without asserting its cause |
| Possible wet areas | Flag appearances that may warrant a moisture or drainage check | Label as a possible condition unless supported by measurements |
| Soil properties | Place available measurements or experimental estimates alongside observations | Choose the properties first; identify the supporting data and validation before presenting an estimate |

Do not assume that the ordinary phone camera provides validated soil chemistry, pH, nutrient levels, or calibrated moisture readings. These capabilities are not established for this project. Unsupported properties should be marked “not assessed,” not populated with plausible numbers.

Each result needs a clear status: **observed**, **estimated**, **measured**, or **not assessed**. Also show whether its source is a recording, a live stationary capture, or a simulation. Avoid a single unexplained “soil health” score.

## 5. Farmer workflow

1. Open a field and see the latest available survey date and evidence age.
2. Open a survey and see its coverage, observations, and inspection priorities.
3. Select a highlighted location to view an image, a plain-language finding, and its evidence status.
4. Choose an inspection action, such as checking a patch on foot or taking a soil sample.
5. Review a short survey summary and record any follow-up findings if time permits.

For the demonstration, replaying a survey also moves a position marker and reveals observations over time. A simulated route represents the concept, not a real flight record. If an image has no verified coordinates, any map placement must be labelled illustrative.

## 6. Proposed dashboard

The panel should answer the farmer's immediate questions before displaying detailed data.

| Area | Contents and purpose |
| --- | --- |
| Survey header | Field name, observation date, evidence age, and explicit live/replay/demo mode |
| Main map | Field boundary if available, current replay position, route, and selectable observations |
| Inspection list | A small ordered list of places to check, with the reason and suggested inspection |
| Selected observation | Source image, capture time, location status, finding, and evidence status |
| Analysis layers | Coverage, unusual patches, possible wet areas, and available soil properties |
| Survey summary | What was observed, what remains unknown, and the proposed next inspections |

Example copy: “Inspect this patch: it looks darker than the surrounding ground. Moisture has not been measured.”

Use “No assessment available” when evidence is missing. Low-quality or missing imagery must not produce a reassuring result. Do not show a confidence percentage unless its meaning is supported.

## 7. Hackathon scope

### Proposed core demonstration

- Show the custom FPV drone and proposed phone attachment as a static physical concept.
- Load one example field or clearly labelled illustrative survey area.
- Replay one short sequence of existing images or footage.
- Show position movement, with simulated telemetry labelled throughout where used.
- Reveal a few observations linked to their source imagery.
- Demonstrate the four analysis categories honestly: supported outputs where available, otherwise “not assessed.”
- End with a concise inspection list that explains what to check and why.

If automatic analysis is not ready, manually prepared observations can demonstrate the product workflow, provided they are labelled as such. They do not demonstrate a working analysis model.

### Optional after the core works

- Stationary phone-camera analysis of a sample or scene, if feasible.
- Compare two observations of the same area at different times.
- Add a farmer's field note or an existing soil test result.
- Export or save a short inspection summary.

### Beyond this hackathon demonstration

Actual flight, autonomous navigation, drone control through the dashboard, validated agronomic diagnosis, and broad farm-management features are outside the proposed demo scope. Real-time airborne phone processing remains a product ambition to assess later.

## 8. Proposed team responsibilities

| Person | Primary responsibility | Reviewable outcome |
| --- | --- | --- |
| Strong technical teammate | Assess analysis feasibility and prepare the observation/replay flow | A repeatable demonstration with clear supported and unsupported outputs |
| Strong social teammate | Clarify farmer needs, prepare the story and presentation | Evidence for the user problem and a concise pitch |
| Project owner / generalist | Own scope, dashboard experience, and integration; connect hardware and software stories | A coherent end-to-end demo and a clear account of what actually works |

The role split above remains proposed. The confirmed assignment is that a teammate owns choosing the analysis target and sourcing the dataset; their identity within the role split is unspecified. Review the demo together at each milestone. The social contributor can validate the central question with potential users: “How do you currently decide which part of a field to inspect first?”

For the dataset handoff, record the source and reuse terms, a few example images or records, what the data supports analysing, and whether timestamps, locations, labels, or reference measurements are available. The team can then agree on what the dashboard may claim.

## 9. Delivery stages

The confirmed deadline is **19:00 today, 7 November 2026, Cork local time**. The following checkpoints are proposed, based on planning at approximately 10:51. Work on the story, physical display, and dashboard layout can proceed while the teammate investigates data. Technical implementation choices remain deferred.

| Target time | Milestone | Exit condition |
| --- | --- | --- |
| 11:30 | Analysis and data checkpoint | Teammate reports the best candidate target and data, or the obstacle; team agrees on a feasible demonstration |
| 12:30 | Demo content and layout agreed | Example material, intended observations, dashboard contents, and physical display plan are clear |
| 15:30 | First complete demo | Survey replay connects position, imagery, findings, and inspection actions |
| 17:00 | Integration review | Dashboard and physical construction tell one coherent story; unsupported claims are removed |
| 18:00 | Feature freeze | Core demo is repeatable; optional work stops; pitch and backup recording are ready |
| 18:30 | Submission readiness | Required submission materials are checked and ready, with time for upload issues |
| 19:00 | Deadline | Submit by the organiser's deadline |

If time becomes tight, preserve the evidence-to-inspection journey and remove optional features first.

If no suitable dataset emerges at the first checkpoint, agree on a smaller demonstrable target or the already documented manual-annotation fallback. Any manual or illustrative content must remain labelled. The broader four-area vision remains in the roadmap.

## 10. Demo story

Adapt this sequence to the presentation slot once its length is known.

1. **Problem:** A farmer has limited time to inspect a field and needs to know where to start.
2. **Physical concept:** Show the custom drone and phone construction. Explain the intended camera and onboard-computing roles, and state that no flight is being demonstrated.
3. **Existing evidence:** Open the sample survey, identify its source, and show the capture date.
4. **Dashboard:** Run the replay; show position, imagery, and emerging observations. Explain any simulated parts.
5. **Decision:** Select one location, explain the evidence, and show the proposed inspection action.
6. **Next step:** Describe the planned path to real-time airborne observations and validated analysis, without presenting either as completed.

Prepare a local presentation path and a short recording of the dashboard in case the demonstration cannot run at the venue. The physical construction and saved evidence should remain understandable on their own.

## 11. Definition of a successful hackathon demo

- A viewer can explain who the product helps and what decision it supports.
- The dashboard connects at least one real source image to a visible observation and a proposed inspection action.
- Position movement works in replay and is labelled correctly as recorded or simulated.
- Capture time is distinct from replay time, so old evidence cannot look newly captured.
- Missing analysis and unknown properties remain visible as unknown.
- Recorded data, manual annotations, automated outputs, and simulations are distinguishable.
- The team can repeat the demonstration without flying the drone.
- The pitch distinguishes demonstrated capabilities from future ambitions.

## 12. Open questions and decisions

| Question | Current status | Why it matters |
| --- | --- | --- |
| What is the submission deadline and presentation length? | Deadline confirmed: 19:00 today, Cork local time. Presentation length remains open | Sets the delivery schedule and demo length |
| Are there additional judging criteria or data-source requirements? | Open | Confirms how the project will be assessed |
| Which existing footage, images, or field records can we use? | Teammate owns the search, which is underway; no dataset selected yet | Anchors the demonstration in evidence |
| Which soil properties matter first? | Teammate will choose the initial analysis target alongside dataset selection; broader ambition retained | Defines what supporting measurements or validation would be needed |
| Who is the first user: farmer, agronomist, or another field operator? | Farmer/field manager proposed | Shapes the wording and inspection workflow |
| Can we show the phone attached in the static construction? | Attachment intended; construction readiness open | Determines what the physical demonstration can honestly show |
| Will any phone-based analysis run during the demo? | Open; stationary capture is optional | Separates working computation from the replay story |
| What should the project be called? | Corkathon is the working name | Finalises the presentation identity |

Technical choices are deliberately deferred: framework, communication method, model, position source, image-to-map alignment, deployment, storage, and phone performance. Once the product and evidence are agreed, these can become a short implementation plan.
