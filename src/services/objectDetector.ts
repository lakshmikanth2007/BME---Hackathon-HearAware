import * as cocoSsd from '@tensorflow-models/coco-ssd';
import '@tensorflow/tfjs';
import { DetectedObject, ObstacleAlert } from '../types/awareness';

const OBSTACLE_CLASSES = new Set([
  'chair',
  'couch',
  'dining table',
  'bed',
  'person',
  'toilet',
  'tv',
  'potted plant',
  'bench',
  'refrigerator',
  'motorcycle',
  'bicycle',
  'car',
]);

const SYNONYMS: Record<string, string[]> = {
  phone: ['cell phone'],
  keys: ['cell phone', 'remote', 'mouse'],
  cup: ['cup', 'bottle', 'wine glass'],
  glass: ['cup', 'wine glass', 'bottle'],
  bottle: ['bottle', 'cup', 'wine glass'],
  table: ['dining table'],
  couch: ['couch', 'chair'],
  sofa: ['couch', 'chair'],
  computer: ['laptop', 'tv'],
  screen: ['laptop', 'tv', 'cell phone'],
  bag: ['backpack', 'handbag', 'suitcase'],
  chair: ['chair', 'couch', 'bench'],
};

export class ObjectDetectionService {
  private model: cocoSsd.ObjectDetection | null = null;
  private isLoading = false;
  private isModelReady = false;

  public async loadModel(): Promise<boolean> {
    if (this.isModelReady) return true;
    if (this.isLoading) return false;

    this.isLoading = true;
    try {
      this.model = await cocoSsd.load({ base: 'lite_mobilenet_v2' });
      this.isModelReady = true;
      this.isLoading = false;
      return true;
    } catch (err) {
      console.warn('Failed to load COCO-SSD model:', err);
      this.isLoading = false;
      return false;
    }
  }

  public get isReady(): boolean {
    return this.isModelReady;
  }

  public async detectFrame(
    element: HTMLVideoElement | HTMLImageElement | HTMLCanvasElement
  ): Promise<DetectedObject[]> {
    if (!this.model || !this.isModelReady) {
      return [];
    }

    // If it's a video, verify it has loaded data
    if (element instanceof HTMLVideoElement) {
      if (element.readyState < 2 || element.videoWidth === 0) {
        return [];
      }
    }

    try {
      const predictions = await this.model.detect(element, 10, 0.4);
      const vWidth =
        element instanceof HTMLVideoElement
          ? element.videoWidth || 640
          : element instanceof HTMLImageElement
          ? element.naturalWidth || 640
          : element.width || 640;

      const vHeight =
        element instanceof HTMLVideoElement
          ? element.videoHeight || 480
          : element instanceof HTMLImageElement
          ? element.naturalHeight || 480
          : element.height || 480;

      return predictions.map((pred, idx) => {
        const [x, y, w, h] = pred.bbox;
        const centerX = x + w / 2;
        const relativeX = centerX / vWidth;

        // Direction from user's perspective
        let direction: 'left' | 'ahead' | 'right' = 'ahead';
        if (relativeX < 0.35) {
          direction = 'left';
        } else if (relativeX > 0.65) {
          direction = 'right';
        }

        // Distance estimation based on bounding box size
        const areaFraction = (w * h) / (vWidth * vHeight);
        const heightFraction = h / vHeight;

        let distanceFt = 10;
        let distanceLabel: DetectedObject['distanceLabel'] = 'far (>10 ft)';

        if (heightFraction > 0.55 || areaFraction > 0.35) {
          distanceFt = 1.5;
          distanceLabel = 'very close (1-2 ft)';
        } else if (heightFraction > 0.3 || areaFraction > 0.15) {
          distanceFt = 3.5;
          distanceLabel = 'close (3-5 ft)';
        } else if (heightFraction > 0.15 || areaFraction > 0.05) {
          distanceFt = 7;
          distanceLabel = 'moderate (6-10 ft)';
        } else {
          distanceFt = 12;
          distanceLabel = 'far (>10 ft)';
        }

        const isObstacle =
          OBSTACLE_CLASSES.has(pred.class.toLowerCase()) &&
          (distanceLabel === 'very close (1-2 ft)' || distanceLabel === 'close (3-5 ft)');

        return {
          id: `det_${idx}_${pred.class}`,
          class: pred.class,
          score: pred.score,
          bbox: [x, y, w, h],
          direction,
          distanceFt,
          distanceLabel,
          isObstacle,
        };
      });
    } catch (err) {
      console.warn('Detection error:', err);
      return [];
    }
  }

  // Check for immediate obstacles in user's direct path
  public checkObstacleAhead(detections: DetectedObject[]): ObstacleAlert | null {
    const obstacle = detections.find(
      (d) =>
        d.isObstacle &&
        d.direction === 'ahead' &&
        (d.distanceLabel === 'very close (1-2 ft)' || d.distanceLabel === 'close (3-5 ft)')
    );

    if (obstacle) {
      return {
        id: `obs_${Date.now()}`,
        timestamp: new Date(),
        objectName: obstacle.class,
        direction: obstacle.direction,
        distanceLabel: obstacle.distanceLabel,
        distanceFt: obstacle.distanceFt,
      };
    }
    return null;
  }

  // Find a specific target object requested by user
  public findTarget(detections: DetectedObject[], targetQuery: string): DetectedObject | null {
    if (!targetQuery) return null;
    const cleanQuery = targetQuery.toLowerCase().trim();

    // Check direct class match
    let match = detections.find((d) => d.class.toLowerCase() === cleanQuery);
    if (match) return match;

    // Check partial substring match
    match = detections.find((d) => d.class.toLowerCase().includes(cleanQuery));
    if (match) return match;

    // Check synonyms
    const altClasses = SYNONYMS[cleanQuery] || [];
    for (const alt of altClasses) {
      const altMatch = detections.find((d) => d.class.toLowerCase() === alt);
      if (altMatch) return altMatch;
    }

    return null;
  }
}

export const objectDetector = new ObjectDetectionService();
