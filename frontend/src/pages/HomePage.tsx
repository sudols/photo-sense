import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { listPhotos, uploadPhoto } from "@/api/photos";
import type { Photo } from "@/api/types";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Alert, AlertDescription } from "@/components/ui/alert";

function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const photoDate = new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate()
  );
  const diffDays = Math.floor(
    (today.getTime() - photoDate.getTime()) / (1000 * 60 * 60 * 24)
  );

  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

function groupByDate(photos: Photo[]): Map<string, Photo[]> {
  const groups = new Map<string, Photo[]>();
  for (const photo of photos) {
    const dateKey = new Date(photo.created_at).toISOString().slice(0, 10);
    const existing = groups.get(dateKey);
    if (existing) {
      existing.push(photo);
    } else {
      groups.set(dateKey, [photo]);
    }
  }
  return groups;
}

export default function HomePage() {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    listPhotos()
      .then(setPhotos)
      .catch(() => setError("Failed to load photos"))
      .finally(() => setLoading(false));
  }, []);

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setError("");
    try {
      const newPhoto = await uploadPhoto(file);
      setPhotos((prev) => [newPhoto, ...prev]);
    } catch {
      setError("Upload failed. Please try again.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <Skeleton className="h-8 w-24" />
          <Skeleton className="h-10 w-24" />
        </div>
        <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-1">
          {Array.from({ length: 16 }).map((_, i) => (
            <Skeleton key={i} className="aspect-square" />
          ))}
        </div>
      </div>
    );
  }

  const groups = groupByDate(photos);
  const sortedGroups = [...groups.entries()].sort(
    (a, b) => b[0].localeCompare(a[0]) // newest first
  );

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold">Photos</h2>
        <div>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handleUpload}
          />
          <Button
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
          >
            {uploading ? "Uploading & Analyzing..." : "Upload"}
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {photos.length === 0 ? (
        <div className="text-center py-20">
          <p className="text-muted-foreground mb-4">
            No photos yet. Upload your first photo!
          </p>
          <Button
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
          >
            {uploading ? "Uploading & Analyzing..." : "Upload Photo"}
          </Button>
        </div>
      ) : (
        sortedGroups.map(([dateKey, groupPhotos]) => (
          <div key={dateKey}>
            <h3 className="text-sm font-medium text-muted-foreground mb-2">
              {formatDate(groupPhotos[0].created_at)}
            </h3>
            <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-1">
              {groupPhotos.map((photo) => (
                <button
                  key={photo.id}
                  onClick={() => navigate(`/photos/${photo.id}`)}
                  className="aspect-square overflow-hidden rounded-sm hover:opacity-80 transition-opacity focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  <img
                    src={photo.url}
                    alt=""
                    className="w-full h-full object-cover"
                    loading="lazy"
                  />
                </button>
              ))}
            </div>
          </div>
        ))
      )}
    </div>
  );
}
