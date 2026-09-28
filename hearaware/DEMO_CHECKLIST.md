# Manual demo checklist

## Before the judges arrive
- [ ] `python backend/scripts/check_env.py` -> all OK (models cached once with internet; after that offline works)
- [ ] `uvicorn app.main:app --host 0.0.0.0 --port 8000` running; `GET /api/health` shows `all_ready: true`
- [ ] Phone and laptop on the same Wi-Fi (or laptop hotspot); server address saved in Settings
- [ ] Volume up, TalkBack off for the demo phone (or on, if showing accessibility)
- [ ] App installed; camera/mic permissions granted once

## Demo Mode (deterministic fallback, always works)
1. Onboarding: tap **BLIND** -> hear "Blind profile selected" -> Try Demo First
2. Switch to **DEMO MODE** -> START AWARENESS MODE
3. Scenario "Car + horn on left" -> hear **"Vehicle horn on your left."** (one message, not car + horn)
4. Scenario "Alarm" -> **"Alarm detected."**
5. Scenario "Person speaking" -> **"Someone says: Your bus is here"**
6. Scenario "Background activity" -> silence; counter shows **6 background events filtered**
7. Settings -> profile **DEAF** -> repeat 3-5 -> large visual alert, arrow + LEFT, pulses, stays until GOT IT
8. History shows the delivered alerts only

## Real Mode (proves it is not fake)
1. REAL MODE -> START; camera + mic pills turn "on", "AI ready" pill appears
2. Point camera at a person/car image on a screen: Blind hears it once (no repeats within cooldown)
3. Play a car-horn / siren clip near the phone: Blind hears "Horn detected. Direction uncertain." (or fused with a visible car)
4. Speak a sentence: transcript appears (Blind hears it; Deaf sees it as text)
5. Stop the backend mid-run: app shows a clear message and reconnects, never crashes
6. Deny a permission in Android settings: clear "permission is required" message

## The message to land
"AI does not simply detect everything. HearAware understands what matters and communicates it the way the user can access it."
