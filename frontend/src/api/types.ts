export interface Photo {
  id: string;
  s3_key: string;
  url: string;
  face_ids: string[];
  detected_text: string[];
  detected_faces: DetectedFace[];
  faces_count: number;
  analyzed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface DetectedFace {
  face_id: string;
  bounding_box: BoundingBox;
  confidence: number;
}

export interface BoundingBox {
  Left: number;
  Top: number;
  Width: number;
  Height: number;
}

export interface Person {
  id: string;
  name: string;
  face_id: string;
  face_ids: string[];
  bounding_box: BoundingBox | null;
  thumbnail_s3_key: string;
  thumbnail_url: string | null;
  is_unnamed: boolean;
  created_at: string;
  updated_at: string;
  photos: Photo[] | null;
}
