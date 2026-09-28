export type UserProfile = 'blind' | 'deaf';

export interface UserSettings {
  profile: UserProfile;
  userName: string;
  speechRate: number;
  hapticFeedback: boolean;
  flashAlerts: boolean;
}

export interface SpeechTranscriptItem {
  id: string;
  timestamp: Date;
  speaker: string;
  text: string;
  isCallingName?: boolean;
  direction?: 'left' | 'ahead' | 'right' | 'behind' | 'unknown';
}

export type EnvironmentalSoundType =
  | 'doorbell'
  | 'horn'
  | 'blast'
  | 'knock'
  | 'name_called'
  | 'alarm'
  | 'dog_bark';

export interface SoundAlert {
  id: string;
  timestamp: Date;
  type: EnvironmentalSoundType;
  title: string;
  description: string;
  direction: 'left' | 'ahead' | 'right' | 'behind' | 'unknown';
  priority: 'high' | 'medium';
  confidence: number;
}

export interface DetectedObject {
  id: string;
  class: string;
  score: number;
  bbox: [number, number, number, number]; // [x, y, width, height]
  direction: 'left' | 'ahead' | 'right';
  distanceFt: number; // estimated distance in feet
  distanceLabel: 'very close (1-2 ft)' | 'close (3-5 ft)' | 'moderate (6-10 ft)' | 'far (>10 ft)';
  isObstacle: boolean;
}

export interface ObstacleAlert {
  id: string;
  timestamp: Date;
  objectName: string;
  direction: 'left' | 'ahead' | 'right';
  distanceLabel: string;
  distanceFt: number;
}
