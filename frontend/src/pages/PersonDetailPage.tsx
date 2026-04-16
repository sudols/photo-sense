import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { getPerson, renamePerson, deletePerson, mergePerson, listPersons } from "@/api/persons";
import type { Person } from "@/api/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function PersonDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [person, setPerson] = useState<Person | null>(null);
  const [loading, setLoading] = useState(true);
  const [nameInput, setNameInput] = useState("");
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [mergeDialogOpen, setMergeDialogOpen] = useState(false);
  const [allPersons, setAllPersons] = useState<Person[]>([]);
  const [selectedMergeTarget, setSelectedMergeTarget] = useState<string>("");
  const [merging, setMerging] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  useEffect(() => {
    if (!id) return;
    getPerson(id)
      .then((p) => {
        setPerson(p);
        setNameInput(p.name);
      })
      .catch(() => setError("Failed to load person"))
      .finally(() => setLoading(false));
  }, [id]);

  async function handleRename() {
    if (!id || !nameInput.trim()) return;
    setSaving(true);
    setError("");
    try {
      const updated = await renamePerson(id, nameInput.trim());
      setPerson(updated);
      setSuccess("Name updated");
      setTimeout(() => setSuccess(""), 2000);
    } catch {
      setError("Failed to rename person");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!id) return;
    setDeleting(true);
    try {
      await deletePerson(id);
      navigate("/people");
    } catch {
      setError("Failed to delete person");
      setDeleteDialogOpen(false);
    } finally {
      setDeleting(false);
    }
  }

  async function openMergeDialog() {
    const others = await listPersons();
    setAllPersons(others.filter((p) => p.id !== id));
    setSelectedMergeTarget("");
    setMergeDialogOpen(true);
  }

  async function handleMerge() {
    if (!id || !selectedMergeTarget) return;
    setMerging(true);
    try {
      await mergePerson(id, selectedMergeTarget);
      navigate(`/people/${selectedMergeTarget}`);
    } catch {
      setError("Failed to merge persons");
      setMergeDialogOpen(false);
    } finally {
      setMerging(false);
    }
  }

  if (loading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-8 w-20" />
        <div className="flex items-center gap-4">
          <Skeleton className="w-24 h-24 rounded-full" />
          <div className="space-y-2">
            <Skeleton className="h-6 w-40" />
            <Skeleton className="h-4 w-24" />
          </div>
        </div>
      </div>
    );
  }

  if (!person) {
    return (
      <Alert variant="destructive">
        <AlertDescription>Person not found</AlertDescription>
      </Alert>
    );
  }

  const initials = person.name
    .split(" ")
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="space-y-6">
      <Button variant="ghost" size="sm" onClick={() => navigate("/people")}>
        &larr; Back
      </Button>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}
      {success && (
        <Alert>
          <AlertDescription>{success}</AlertDescription>
        </Alert>
      )}

      <div className="flex items-center gap-4">
        {person.thumbnail_url ? (
          <img
            src={person.thumbnail_url}
            alt={person.name}
            className="w-24 h-24 rounded-full object-cover"
          />
        ) : (
          <Avatar className="w-24 h-24">
            <AvatarFallback className="text-2xl">{initials}</AvatarFallback>
          </Avatar>
        )}
        <div>
          <h2 className="text-xl font-bold">{person.name}</h2>
          <Badge variant="secondary">
            {person.face_ids.length} face{person.face_ids.length !== 1 && "s"}
          </Badge>
        </div>
      </div>

      <Separator />

      <section className="space-y-3">
        <h3 className="text-sm font-medium">Rename</h3>
        <div className="flex gap-2">
          <Input
            value={nameInput}
            onChange={(e) => setNameInput(e.target.value)}
            placeholder="Enter name"
            onKeyDown={(e) => e.key === "Enter" && handleRename()}
          />
          <Button onClick={handleRename} disabled={saving || !nameInput.trim()}>
            {saving ? "Saving..." : "Save"}
          </Button>
        </div>
      </section>

      <Separator />

      <section className="space-y-3">
        <h3 className="text-sm font-medium">Actions</h3>
        <div className="flex gap-2">
          <Button variant="outline" onClick={openMergeDialog}>
            Merge with another person
          </Button>
          <Button
            variant="destructive"
            onClick={() => setDeleteDialogOpen(true)}
          >
            Delete Person
          </Button>
        </div>
      </section>

      <Separator />

      {person.photos && person.photos.length > 0 && (
        <section>
          <h3 className="text-sm font-medium text-muted-foreground mb-2">
            Photos ({person.photos.length})
          </h3>
          <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-1">
            {person.photos.map((photo) => (
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
        </section>
      )}

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete Person</DialogTitle>
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

      <Dialog open={mergeDialogOpen} onOpenChange={setMergeDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Merge Person</DialogTitle>
            <DialogDescription>
              Select a person to merge &quot;{person.name}&quot; into. The
              selected person will keep their name and absorb all faces.
            </DialogDescription>
          </DialogHeader>
          <div className="max-h-60 overflow-y-auto space-y-1 py-2">
            {allPersons.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-4">
                No other persons to merge with.
              </p>
            ) : (
              allPersons.map((p) => (
                <button
                  key={p.id}
                  onClick={() => setSelectedMergeTarget(p.id)}
                  className={`w-full flex items-center gap-3 p-2 rounded-md transition-colors ${
                    selectedMergeTarget === p.id
                      ? "bg-primary text-primary-foreground"
                      : "hover:bg-muted"
                  }`}
                >
                  {p.thumbnail_url ? (
                    <img
                      src={p.thumbnail_url}
                      alt=""
                      className="w-8 h-8 rounded-full object-cover"
                    />
                  ) : (
                    <Avatar className="w-8 h-8">
                      <AvatarFallback className="text-xs">
                        {p.name
                          .split(" ")
                          .map((w) => w[0])
                          .join("")
                          .slice(0, 2)
                          .toUpperCase()}
                      </AvatarFallback>
                    </Avatar>
                  )}
                  <span className="text-sm font-medium">{p.name}</span>
                  <Badge
                    variant={
                      selectedMergeTarget === p.id ? "secondary" : "outline"
                    }
                    className="ml-auto"
                  >
                    {p.face_ids.length} face{p.face_ids.length !== 1 && "s"}
                  </Badge>
                </button>
              ))
            )}
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setMergeDialogOpen(false)}
              disabled={merging}
            >
              Cancel
            </Button>
            <Button
              onClick={handleMerge}
              disabled={merging || !selectedMergeTarget}
            >
              {merging ? "Merging..." : "Merge"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
