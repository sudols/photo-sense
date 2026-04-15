import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { getPhoto, deletePhoto } from "@/api/photos";
import type { Photo } from "@/api/types";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function PhotoDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [photo, setPhoto] = useState<Photo | null>(null);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!id) return;
    getPhoto(id)
      .then(setPhoto)
      .catch(() => setError("Failed to load photo"))
      .finally(() => setLoading(false));
  }, [id]);

  async function handleDelete() {
    if (!id) return;
    setDeleting(true);
    try {
      await deletePhoto(id);
      navigate("/");
    } catch {
      setError("Failed to delete photo");
      setDeleteDialogOpen(false);
    } finally {
      setDeleting(false);
    }
  }

  if (loading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-8 w-20" />
        <Skeleton className="max-w-2xl mx-auto aspect-[4/3] w-full" />
        <div className="space-y-2">
          <Skeleton className="h-4 w-32" />
          <Skeleton className="h-4 w-48" />
        </div>
      </div>
    );
  }

  if (!photo) {
    return (
      <Alert variant="destructive">
        <AlertDescription>Photo not found</AlertDescription>
      </Alert>
    );
  }

  const formattedDate = new Date(photo.created_at).toLocaleDateString(
    "en-US",
    {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <Button variant="ghost" size="sm" onClick={() => navigate("/")}>
          &larr; Back
        </Button>
        <Button
          variant="destructive"
          size="sm"
          onClick={() => setDeleteDialogOpen(true)}
        >
          Delete Photo
        </Button>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      <div className="flex justify-center">
        <img
          src={photo.url}
          alt=""
          className="max-w-full max-h-[70vh] object-contain rounded-lg"
        />
      </div>

      <div className="space-y-3 max-w-2xl mx-auto">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-muted-foreground">
            Faces Detected:
          </span>
          <Badge variant="secondary">{photo.faces_count}</Badge>
        </div>

        {photo.detected_text.length > 0 && (
          <div>
            <span className="text-sm font-medium text-muted-foreground">
              Detected Text:
            </span>
            <div className="flex flex-wrap gap-1 mt-1">
              {photo.detected_text.map((text, i) => (
                <Badge key={i} variant="outline">
                  {text}
                </Badge>
              ))}
            </div>
          </div>
        )}

        {photo.analyzed_at && (
          <div>
            <span className="text-sm font-medium text-muted-foreground">
              Analyzed:
            </span>
            <span className="text-sm ml-2">
              {new Date(photo.analyzed_at).toLocaleString()}
            </span>
          </div>
        )}

        <div>
          <span className="text-sm font-medium text-muted-foreground">
            Uploaded:
          </span>
          <span className="text-sm ml-2">{formattedDate}</span>
        </div>
      </div>

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete Photo</DialogTitle>
            <DialogDescription>
              Are you sure? This cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setDeleteDialogOpen(false)}
              disabled={deleting}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleDelete}
              disabled={deleting}
            >
              {deleting ? "Deleting..." : "Delete"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
