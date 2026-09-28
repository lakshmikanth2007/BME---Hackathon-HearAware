import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Activity,
  AlertTriangle,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  Camera,
  CheckCircle,
  ExternalLink,
  Eye,
  Mic,
  MicOff,
  Radio,
  RefreshCw,
  Settings as SettingsIcon,
  Shield,
  User,
  Volume2,
  VolumeX,
} from 'lucide-react';
import {
  UserProfile,
  UserSettings,
  SpeechTranscriptItem,
  SoundAlert,
  DetectedObject,
  ObstacleAlert,
} from './types/awareness';
import { hardwareSensors, SensorStatus } from './services/hardwareSensors';
import { audioAnalyzer } from './services/audioAnalyzer';
import { speechService } from './services/speechService';
import { objectDetector } from './services/objectDetector';
import { soundService } from './services/soundService';
import { DeafView } from './components/DeafView';
import { BlindView } from './components/BlindView';

const STORAGE_SETTINGS = 'hearaware_v2_settings';

export const App: React.FC = () => {
  // 1. Settings & Profile
  const [settings, setSettings] = useState<UserSettings>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_SETTINGS);
      if (saved) {
        return JSON.parse(saved);
      }
    } catch {
      // ignore
    }
    return {
      profile: 'deaf',
      userName: 'Alex',
      speechRate: 1.0,
      hapticFeedback: true,
      flashAlerts: true,
    };
  });

  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [isRunning, setIsRunning] = useState(false);

  // 2. Hardware Sensors Status
  const [sensorStatus, setSensorStatus] = useState<SensorStatus>({
    camera: 'off',
    mic: 'off',
  });
  const [mediaStream, setMediaStream] = useState<MediaStream | null>(null);
  const [micVolume, setMicVolume] = useState<number>(0);
  const [frequencyBands, setFrequencyBands] = useState<number[]>([0, 0, 0, 0, 0, 0, 0, 0]);
  const [speechError, setSpeechError] = useState<string | undefined>(undefined);

  // 3. Deaf Mode State
  const [transcripts, setTranscripts] = useState<SpeechTranscriptItem[]>([]);
  const [interimTranscript, setInterimTranscript] = useState<string>('');
  const [activeSoundAlert, setActiveSoundAlert] = useState<SoundAlert | null>(null);
  const [nameCallingAlert, setNameCallingAlert] = useState<{
    phrase: string;
    direction: 'left' | 'ahead' | 'right';
  } | null>(null);

  // 4. Blind Mode State
  const [detectedObjects, setDetectedObjects] = useState<DetectedObject[]>([]);
  const [targetQuery, setTargetQuery] = useState<string | null>(null);
  const [foundTarget, setFoundTarget] = useState<DetectedObject | null>(null);
  const [activeObstacle, setActiveObstacle] = useState<ObstacleAlert | null>(null);
  const [lastVoiceCommand, setLastVoiceCommand] = useState<string | null>(null);
  const [isModelLoading, setIsModelLoading] = useState(false);

  // Video Element Ref
  const videoElementRef = useRef<HTMLVideoElement>(null);
  const detectionAnimRef = useRef<number | null>(null);
  const lastTargetAnnounceRef = useRef<number>(0);
  const lastObstacleAnnounceRef = useRef<number>(0);
  const lastNameAlertRef = useRef<number>(0);
  const lastGuidanceDirectionRef = useRef<string>('');

  const isInIframe = typeof window !== 'undefined' && window.self !== window.top;

  // Save settings helper
  const updateSettings = (updates: Partial<UserSettings>) => {
    setSettings((prev) => {
      const next = { ...prev, ...updates };
      try {
        localStorage.setItem(STORAGE_SETTINGS, JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  // Announce for blind users
  const announceSpoken = useCallback(
    (text: string, interrupt = false) => {
      if (settings.profile === 'blind') {
        speechService.speak(text, {
          rate: settings.speechRate,
          interrupt,
        });
      }
    },
    [settings.profile, settings.speechRate]
  );

  // Handle Object Finding Search Command
  const handleSetTarget = useCallback(
    (target: string | null) => {
      setTargetQuery(target);
      setFoundTarget(null);
      if (target) {
        announceSpoken(`Searching for ${target}. Pan your camera around the room.`, true);
      } else {
        announceSpoken('Object search cancelled.', true);
      }
    },
    [announceSpoken]
  );

  // Handle Voice Commands from Blind Profile
  const handleVoiceCommand = useCallback(
    (cmd: {
      action: 'find' | 'describe' | 'stop' | 'help' | 'obstacles';
      target?: string;
      raw: string;
    }) => {
      setLastVoiceCommand(cmd.raw);

      switch (cmd.action) {
        case 'find':
          if (cmd.target) {
            handleSetTarget(cmd.target);
          }
          break;
        case 'stop':
          handleSetTarget(null);
          break;
        case 'describe':
          if (detectedObjects.length === 0) {
            announceSpoken('I do not see any objects in view right now.', true);
          } else {
            const summary = detectedObjects
              .slice(0, 3)
              .map(
                (d) =>
                  `${d.class} ${d.direction === 'ahead' ? 'directly ahead' : `on your ${d.direction}`}`
              )
              .join(', and ');
            announceSpoken(`In front of you: ${summary}.`, true);
          }
          break;
        case 'obstacles':
          if (activeObstacle) {
            announceSpoken(
              `Obstacle: ${activeObstacle.objectName} is ${
                activeObstacle.direction === 'ahead'
                  ? 'directly ahead'
                  : `on your ${activeObstacle.direction}`
              }, ${activeObstacle.distanceLabel}.`,
              true
            );
          } else {
            announceSpoken('Your path ahead is clear of immediate obstacles.', true);
          }
          break;
        case 'help':
          announceSpoken(
            'HearAware voice activation is on. You can say Find bottle, Find chair, Find phone, Describe surroundings, or Check obstacles.',
            true
          );
          break;
      }
    },
    [activeObstacle, announceSpoken, detectedObjects, handleSetTarget]
  );

  // Real-time Computer Vision Loop
  useEffect(() => {
    if (!isRunning || !mediaStream) {
      if (detectionAnimRef.current) {
        cancelAnimationFrame(detectionAnimRef.current);
        detectionAnimRef.current = null;
      }
      return;
    }

    let isDetecting = false;
    let frameCounter = 0;

    const runVision = async () => {
      frameCounter++;
      // Process every 5 frames for smooth tracking and high performance
      if (frameCounter % 5 === 0 && !isDetecting && videoElementRef.current) {
        const video = videoElementRef.current;
        if (video.readyState >= 2 && video.videoWidth > 0) {
          isDetecting = true;
          try {
            const detections = await objectDetector.detectFrame(video);
            setDetectedObjects(detections);

            const now = Date.now();

            if (targetQuery) {
              // WHILE FINDING AN OBJECT: Suppress obstacle alerts completely!
              // Focus exclusively on directing the user to the target object.
              setActiveObstacle(null);

              const found = objectDetector.findTarget(detections, targetQuery);
              setFoundTarget(found);

              if (found && settings.profile === 'blind') {
                const directionChanged = lastGuidanceDirectionRef.current !== found.direction;
                const timeElapsed = now - lastTargetAnnounceRef.current;

                // Announce every 6 seconds, or immediately if user successfully centered the object
                if (timeElapsed > 6000 || (directionChanged && found.direction === 'ahead' && timeElapsed > 2500)) {
                  lastTargetAnnounceRef.current = now;
                  lastGuidanceDirectionRef.current = found.direction;
                  soundService.playAlertSound(false);

                  let directionPrompt = '';
                  if (found.direction === 'left') {
                    directionPrompt = `Turn slightly left. ${found.class} is on your left, ${found.distanceLabel}.`;
                  } else if (found.direction === 'right') {
                    directionPrompt = `Turn slightly right. ${found.class} is on your right, ${found.distanceLabel}.`;
                  } else {
                    // Directly ahead
                    if (found.distanceLabel === 'very close (1-2 ft)') {
                      directionPrompt = `${found.class} is directly ahead within arm's reach! Reach forward.`;
                    } else if (found.distanceLabel === 'close (3-5 ft)') {
                      directionPrompt = `${found.class} is straight ahead, about 3 to 4 feet away. Take two steps forward.`;
                    } else {
                      directionPrompt = `${found.class} is straight ahead, ${found.distanceLabel}. Move forward.`;
                    }
                  }

                  announceSpoken(directionPrompt, true);
                }
              }
            } else {
              // WHEN NOT FINDING AN OBJECT: Monitor and alert about obstacles ahead
              // Reduced frequency: only warn every 8.5 seconds to avoid alert fatigue
              const obstacle = objectDetector.checkObstacleAhead(detections);
              setActiveObstacle(obstacle);

              if (obstacle && settings.profile === 'blind' && now - lastObstacleAnnounceRef.current > 8500) {
                lastObstacleAnnounceRef.current = now;
                soundService.playAlertSound(true);
                announceSpoken(
                  `Obstacle: ${obstacle.objectName} is ${
                    obstacle.direction === 'ahead' ? 'directly ahead' : `on your ${obstacle.direction}`
                  }, ${obstacle.distanceLabel}.`,
                  true
                );
              }
            }
          } catch (e) {
            console.warn('Vision loop error:', e);
          } finally {
            isDetecting = false;
          }
        }
      }

      detectionAnimRef.current = requestAnimationFrame(runVision);
    };

    detectionAnimRef.current = requestAnimationFrame(runVision);

    return () => {
      if (detectionAnimRef.current) {
        cancelAnimationFrame(detectionAnimRef.current);
        detectionAnimRef.current = null;
      }
    };
  }, [isRunning, settings.profile, mediaStream, targetQuery, announceSpoken]);

  // Handle uploaded test image for object/obstacle detection
  const handleImageUploaded = async (img: HTMLImageElement) => {
    if (!objectDetector.isReady) {
      await objectDetector.loadModel();
    }
    const detections = await objectDetector.detectFrame(img);
    setDetectedObjects(detections);

    if (detections.length === 0) {
      announceSpoken('No recognizable objects detected in this photo.', true);
    } else {
      if (targetQuery) {
        setActiveObstacle(null);
        const found = objectDetector.findTarget(detections, targetQuery);
        setFoundTarget(found);
        if (found) {
          let directionPrompt = '';
          if (found.direction === 'left') {
            directionPrompt = `Found ${found.class} on your left, ${found.distanceLabel}. Turn left.`;
          } else if (found.direction === 'right') {
            directionPrompt = `Found ${found.class} on your right, ${found.distanceLabel}. Turn right.`;
          } else {
            directionPrompt = `Found ${found.class} directly ahead, ${found.distanceLabel}. Reach forward.`;
          }
          announceSpoken(directionPrompt, true);
          return;
        } else {
          announceSpoken(`${targetQuery} was not detected in this photo. Try another view.`, true);
          return;
        }
      } else {
        const obstacle = objectDetector.checkObstacleAhead(detections);
        setActiveObstacle(obstacle);
      }

      const list = detections.map((d) => d.class).join(', ');
      announceSpoken(`Detected in photo: ${list}.`, true);
    }
  };

  // Start All Perception Engines
  const handleStart = async () => {
    setIsRunning(true);
    setSpeechError(undefined);

    // 1. Preload object detection model
    if (!objectDetector.isReady) {
      setIsModelLoading(true);
      objectDetector.loadModel().then(() => setIsModelLoading(false));
    }

    // 2. Request hardware sensors (unified)
    const { stream, audioTrack, status } = await hardwareSensors.startSensors((st) => {
      setSensorStatus(st);
    });

    setMediaStream(stream);

    // 3. Start audio analyzer for live volume and environmental sound classification
    if (audioTrack) {
      audioAnalyzer.start(
        audioTrack,
        (alert) => {
          // Strictly for DEAF profile: visual environmental sound alerts & tone
          if (settings.profile === 'deaf') {
            soundService.playAlertSound(alert.priority === 'high');
            setActiveSoundAlert(alert);
          }
          // For BLIND profile: DO NOT give alert for environment sounds (as requested)
        },
        (vol, bands) => {
          setMicVolume(vol);
          setFrequencyBands(bands);
        }
      );
    }

    // 4. Start speech service (STT / voice commands / name detection)
    speechService.init({
      profile: settings.profile,
      userName: settings.userName,
      onTranscript: (item, isInterim) => {
        if (isInterim) {
          setInterimTranscript(item.text);
        } else {
          setInterimTranscript('');
          setTranscripts((prev) => [item, ...prev.slice(0, 40)]);
        }
      },
      onNameCalled: (phrase, direction) => {
        const now = Date.now();
        if (now - lastNameAlertRef.current < 12000) return; // 12-second cooldown to reduce alert frequency
        lastNameAlertRef.current = now;

        soundService.playAlertSound(true);
        setNameCallingAlert({ phrase, direction });

        if (settings.profile === 'blind') {
          announceSpoken(
            `Someone is calling your name ${
              direction === 'ahead' ? 'ahead of you' : `on your ${direction}`
            }.`,
            true
          );
        }
      },
      onVoiceCommand: handleVoiceCommand,
      onSpeechStatus: (st) => {
        if (st.error) {
          setSpeechError(st.error);
        }
      },
    });

    speechService.startListening();

    // Spoken greeting for Blind profile
    if (settings.profile === 'blind') {
      announceSpoken(
        'HearAware Blind Mode activated. Camera and microphone running. Everything is voice activated. Say Find bottle, Find chair, or Describe surroundings.',
        true
      );
    }
  };

  // Stop All Perception Engines
  const handleStop = () => {
    hardwareSensors.stopSensors();
    audioAnalyzer.stop();
    speechService.stopListening();
    speechService.stopSpeaking();

    if (detectionAnimRef.current) {
      cancelAnimationFrame(detectionAnimRef.current);
      detectionAnimRef.current = null;
    }

    setMediaStream(null);
    setIsRunning(false);
    setSensorStatus({ camera: 'off', mic: 'off' });
    setActiveSoundAlert(null);
    setNameCallingAlert(null);
    setTargetQuery(null);
    setFoundTarget(null);
    setActiveObstacle(null);
    setMicVolume(0);
    setFrequencyBands([0, 0, 0, 0, 0, 0, 0, 0]);

    if (settings.profile === 'blind') {
      announceSpoken('Awareness stopped.', true);
    }
  };

  // Toggle Profile (Blind vs Deaf)
  const handleSwitchProfile = (newProfile: UserProfile) => {
    updateSettings({ profile: newProfile });
    speechService.setProfile(newProfile);

    if (newProfile === 'blind') {
      if (!objectDetector.isReady) {
        setIsModelLoading(true);
        objectDetector.loadModel().then(() => setIsModelLoading(false));
      }
      announceSpoken('Switched to Blind profile. Everything is voice activated.', true);
    } else {
      speechService.stopSpeaking();
    }
  };

  // Tap screen audio announcement for blind users
  const handleTapScreenAnnounce = () => {
    if (settings.profile === 'blind') {
      const camMsg = sensorStatus.camera === 'active' ? 'Camera active.' : 'Camera off.';
      const micMsg = sensorStatus.mic === 'active' ? 'Voice listening.' : 'Microphone off.';
      const targetMsg = targetQuery
        ? `Currently searching for ${targetQuery}.`
        : 'No object search active.';
      announceSpoken(
        `${camMsg} ${micMsg} ${targetMsg} Say Find followed by any object, or tap Describe.`,
        true
      );
    }
  };

  // Direct speech input processor (works even if browser speech recognition is blocked in iframe)
  const handleDirectSpeechInput = (text: string) => {
    speechService.processText(text, true);
    if (settings.profile === 'blind') {
      announceSpoken(`Input received: ${text}`, true);
    }
  };

  // Clean up on unmount
  useEffect(() => {
    return () => {
      hardwareSensors.stopSensors();
      audioAnalyzer.stop();
      speechService.stopListening();
    };
  }, []);

  return (
    <div className="min-h-screen bg-black text-white flex flex-col items-center">
      {/* Settings Modal */}
      {showSettingsModal && (
        <div
          role="dialog"
          aria-label="User Profile & Settings"
          className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex items-center justify-center p-4"
        >
          <div className="w-full max-w-md bg-[#15151A] border-2 border-neutral-700 rounded-3xl p-6 flex flex-col gap-5 shadow-2xl">
            <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
              <h2 className="text-2xl font-black text-white">Profile & Settings</h2>
              <button
                type="button"
                onClick={() => setShowSettingsModal(false)}
                className="text-neutral-400 hover:text-white font-bold text-sm px-3 py-1.5 rounded-xl bg-neutral-800 cursor-pointer"
              >
                Close
              </button>
            </div>

            {/* Profile Selection */}
            <div>
              <label className="text-sm font-black text-neutral-300 block mb-2 uppercase tracking-wide">
                Choose Profile
              </label>
              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => handleSwitchProfile('blind')}
                  className={`p-4 rounded-2xl border-2 flex flex-col items-center gap-2 cursor-pointer transition-all ${
                    settings.profile === 'blind'
                      ? 'bg-[#FFD60A] border-[#FFD60A] text-black font-black shadow-lg'
                      : 'bg-black border-neutral-800 text-neutral-400 hover:border-neutral-600'
                  }`}
                >
                  <Volume2 className="w-8 h-8" />
                  <span className="text-lg">BLIND</span>
                  <span className="text-xs opacity-80">Voice Activated</span>
                </button>

                <button
                  type="button"
                  onClick={() => handleSwitchProfile('deaf')}
                  className={`p-4 rounded-2xl border-2 flex flex-col items-center gap-2 cursor-pointer transition-all ${
                    settings.profile === 'deaf'
                      ? 'bg-white border-white text-black font-black shadow-lg'
                      : 'bg-black border-neutral-800 text-neutral-400 hover:border-neutral-600'
                  }`}
                >
                  <Eye className="w-8 h-8" />
                  <span className="text-lg">DEAF</span>
                  <span className="text-xs opacity-80">Visual Alerts</span>
                </button>
              </div>
            </div>

            {/* User Name */}
            <div>
              <label className="text-sm font-black text-neutral-300 block mb-1 uppercase tracking-wide">
                Your Name (For Name Calling Alerts)
              </label>
              <p className="text-xs text-neutral-400 mb-2">
                When someone says your name, HearAware alerts you with their direction.
              </p>
              <input
                type="text"
                value={settings.userName}
                onChange={(e) => {
                  updateSettings({ userName: e.target.value });
                  speechService.setUserName(e.target.value);
                }}
                placeholder="e.g. Alex"
                className="w-full px-4 py-3 rounded-2xl bg-black border border-neutral-700 text-white font-bold text-lg focus:border-[#FFD60A] outline-none"
              />
            </div>

            {/* Speech Rate for Blind users */}
            {settings.profile === 'blind' && (
              <div>
                <div className="flex justify-between items-center mb-1">
                  <label className="text-sm font-black text-neutral-300 uppercase tracking-wide">
                    Voice Speed
                  </label>
                  <span className="text-xs font-mono text-[#FFD60A] font-bold">
                    {settings.speechRate.toFixed(1)}x
                  </span>
                </div>
                <input
                  type="range"
                  min="0.7"
                  max="1.5"
                  step="0.1"
                  value={settings.speechRate}
                  onChange={(e) => updateSettings({ speechRate: parseFloat(e.target.value) })}
                  className="w-full accent-[#FFD60A] cursor-pointer"
                />
              </div>
            )}

            <button
              type="button"
              onClick={() => setShowSettingsModal(false)}
              className="w-full py-4 rounded-2xl bg-[#FFD60A] hover:bg-[#e6c008] text-black font-black text-lg uppercase tracking-wider transition-all cursor-pointer shadow-lg mt-2"
            >
              SAVE & DONE
            </button>
          </div>
        </div>
      )}

      {/* Main Container */}
      <div className="w-full max-w-lg mx-auto px-4 py-5 flex-1 flex flex-col">
        {/* App Header */}
        <header className="flex items-center justify-between pb-3">
          <div className="flex items-center gap-2.5">
            <Radio className="w-8 h-8 text-[#FFD60A]" />
            <div>
              <h1 className="text-3xl font-black text-[#FFD60A] tracking-tight leading-none">
                HearAware
              </h1>
              <span className="text-[11px] font-bold text-neutral-400 tracking-wide uppercase">
                Sensory Substitution Platform
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {isInIframe && (
              <a
                href={window.location.href}
                target="_blank"
                rel="noopener noreferrer"
                title="Open in new window for direct camera and microphone access"
                className="p-2.5 rounded-2xl text-neutral-300 hover:text-white bg-[#15151A] border border-neutral-800 active:scale-95 transition-all flex items-center gap-1.5 text-xs font-bold"
              >
                <span>Full Tab</span>
                <ExternalLink className="w-3.5 h-3.5 text-[#FFD60A]" />
              </a>
            )}

            <button
              type="button"
              onClick={() => setShowSettingsModal(true)}
              aria-label="Profile and Settings"
              className="p-2.5 rounded-2xl text-neutral-300 hover:text-white bg-[#15151A] border border-neutral-800 active:scale-95 transition-all flex items-center gap-2 cursor-pointer"
            >
              <User className="w-5 h-5 text-[#FFD60A]" />
              <span className="text-xs font-black uppercase">{settings.userName}</span>
              <SettingsIcon className="w-4 h-4 text-neutral-400" />
            </button>
          </div>
        </header>

        {/* Profile Switcher Pills */}
        <div className="grid grid-cols-2 gap-2 p-1.5 bg-[#15151A] rounded-2xl border border-neutral-800 mb-4">
          <button
            type="button"
            onClick={() => handleSwitchProfile('blind')}
            className={`py-3 px-4 rounded-xl flex items-center justify-center gap-2 font-black text-sm tracking-wider uppercase transition-all cursor-pointer ${
              settings.profile === 'blind'
                ? 'bg-[#FFD60A] text-black shadow-md'
                : 'text-neutral-400 hover:text-white'
            }`}
          >
            <Volume2 className="w-5 h-5" />
            <span>BLIND PROFILE</span>
          </button>

          <button
            type="button"
            onClick={() => handleSwitchProfile('deaf')}
            className={`py-3 px-4 rounded-xl flex items-center justify-center gap-2 font-black text-sm tracking-wider uppercase transition-all cursor-pointer ${
              settings.profile === 'deaf'
                ? 'bg-white text-black shadow-md'
                : 'text-neutral-400 hover:text-white'
            }`}
          >
            <Eye className="w-5 h-5" />
            <span>DEAF PROFILE</span>
          </button>
        </div>

        {/* Sensor Status Bar */}
        <div className="flex items-center justify-between px-4 py-2.5 rounded-2xl bg-[#15151A] border border-neutral-800 mb-4 text-xs font-bold">
          <div className="flex items-center gap-3">
            {/* Camera Status */}
            <div className="flex items-center gap-1.5">
              <Camera
                className={`w-4 h-4 ${
                  sensorStatus.camera === 'active'
                    ? 'text-[#32D74B]'
                    : sensorStatus.camera === 'denied'
                    ? 'text-[#FF453A]'
                    : 'text-neutral-500'
                }`}
              />
              <span className={sensorStatus.camera === 'active' ? 'text-white' : 'text-neutral-400'}>
                Cam: {sensorStatus.camera}
              </span>
            </div>

            {/* Mic Status */}
            <div className="flex items-center gap-1.5">
              <Mic
                className={`w-4 h-4 ${
                  sensorStatus.mic === 'active'
                    ? 'text-[#32D74B]'
                    : sensorStatus.mic === 'denied'
                    ? 'text-[#FF453A]'
                    : 'text-neutral-500'
                }`}
              />
              <span className={sensorStatus.mic === 'active' ? 'text-white' : 'text-neutral-400'}>
                Mic: {sensorStatus.mic}
              </span>
            </div>
          </div>

          {/* AI Vision Model Status */}
          <span className="text-neutral-400 font-mono text-[11px]">
            {isModelLoading ? 'Loading AI...' : 'Vision AI Ready'}
          </span>
        </div>

        {/* Primary Activation Button */}
        <div className="mb-4">
          {!isRunning ? (
            <button
              type="button"
              onClick={handleStart}
              className="w-full min-h-[72px] py-4 rounded-3xl bg-[#FFD60A] hover:bg-[#e6c008] active:scale-[0.98] text-black font-black text-2xl uppercase tracking-wider transition-all cursor-pointer shadow-xl flex items-center justify-center gap-3"
            >
              <Radio className="w-8 h-8 fill-current" />
              <span>START AWARENESS</span>
            </button>
          ) : (
            <button
              type="button"
              onClick={handleStop}
              className="w-full min-h-[64px] py-3.5 rounded-3xl bg-[#FF453A] hover:bg-[#e0382e] active:scale-[0.98] text-white font-black text-xl uppercase tracking-wider transition-all cursor-pointer shadow-xl flex items-center justify-center gap-3"
            >
              <VolumeX className="w-7 h-7" />
              <span>STOP AWARENESS</span>
            </button>
          )}
        </div>

        {/* Dynamic Mode View */}
        {settings.profile === 'deaf' ? (
          <DeafView
            userName={settings.userName}
            transcripts={transcripts}
            interimTranscript={interimTranscript}
            activeSoundAlert={activeSoundAlert}
            nameCallingAlert={nameCallingAlert}
            onDismissSoundAlert={() => setActiveSoundAlert(null)}
            onDismissNameAlert={() => setNameCallingAlert(null)}
            onClearTranscripts={() => setTranscripts([])}
            micActive={sensorStatus.mic === 'active'}
            micVolume={micVolume}
            frequencyBands={frequencyBands}
            micDeviceLabel={sensorStatus.micDeviceLabel}
            speechError={speechError}
            isIframeBlocked={sensorStatus.isIframeBlocked}
            onDirectSpeechInput={handleDirectSpeechInput}
            cameraStream={mediaStream}
            cameraActive={sensorStatus.camera === 'active'}
            cameraError={sensorStatus.cameraError}
            cameraLabel={sensorStatus.cameraDeviceLabel}
            detectedObjects={detectedObjects}
            videoElementRef={videoElementRef}
            onRetryCamera={async () => {
              const res = await hardwareSensors.startSensors((st) => setSensorStatus(st));
              setMediaStream(res.stream);
            }}
            onImageUploaded={handleImageUploaded}
            onTriggerSimulatedSound={(type) => {
              if (type === 'name') {
                soundService.playAlertSound(true);
                setNameCallingAlert({
                  phrase: `Hey ${settings.userName}! Look over here!`,
                  direction: 'ahead',
                });
              } else {
                const map: Record<
                  string,
                  { title: string; desc: string; pri: 'high' | 'medium' }
                > = {
                  doorbell: {
                    title: 'DOORBELL RINGING',
                    desc: 'High-pitch chime or doorbell melody detected',
                    pri: 'medium',
                  },
                  horn: {
                    title: 'CAR HORN BLARING',
                    desc: 'Vehicle horn sounding nearby',
                    pri: 'high',
                  },
                  blast: {
                    title: 'LOUD BLAST DETECTED',
                    desc: 'Sudden explosive sound or heavy impact',
                    pri: 'high',
                  },
                  knock: {
                    title: 'DOOR KNOCKING',
                    desc: 'Rhythmic knocking sound at the door',
                    pri: 'medium',
                  },
                };
                const info = map[type];
                soundService.playAlertSound(info.pri === 'high');
                setActiveSoundAlert({
                  id: `sim_${Date.now()}`,
                  timestamp: new Date(),
                  type: type as any,
                  title: info.title,
                  description: info.desc,
                  direction: 'ahead',
                  priority: info.pri,
                  confidence: 0.95,
                });
              }
            }}
          />
        ) : (
          <BlindView
            videoStream={mediaStream}
            cameraActive={sensorStatus.camera === 'active'}
            cameraError={sensorStatus.cameraError}
            cameraDeviceLabel={sensorStatus.cameraDeviceLabel}
            detectedObjects={detectedObjects}
            targetQuery={targetQuery}
            foundTarget={foundTarget}
            activeObstacle={activeObstacle}
            isVoiceListening={isRunning}
            micActive={sensorStatus.mic === 'active'}
            micVolume={micVolume}
            frequencyBands={frequencyBands}
            micDeviceLabel={sensorStatus.micDeviceLabel}
            speechError={speechError}
            lastVoiceCommand={lastVoiceCommand}
            isIframeBlocked={sensorStatus.isIframeBlocked}
            videoElementRef={videoElementRef}
            onSetTarget={handleSetTarget}
            onTapScreenAnnounce={handleTapScreenAnnounce}
            onManualVoiceInput={(cmd) => {
              speechService.speak(cmd, { rate: settings.speechRate });
              if (/find/i.test(cmd)) {
                const target = cmd.replace(/find/i, '').trim();
                handleSetTarget(target);
              } else if (/describe/i.test(cmd)) {
                handleVoiceCommand({ action: 'describe', raw: cmd });
              } else if (/obstacle/i.test(cmd)) {
                handleVoiceCommand({ action: 'obstacles', raw: cmd });
              } else if (/stop/i.test(cmd)) {
                handleSetTarget(null);
              }
            }}
            onRetryCamera={async () => {
              const res = await hardwareSensors.startSensors((st) => setSensorStatus(st));
              setMediaStream(res.stream);
            }}
            onImageUploaded={handleImageUploaded}
          />
        )}
      </div>
    </div>
  );
};

export default App;
