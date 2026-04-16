import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { searchPhotos } from "@/api/photos";
import type { Photo } from "@/api/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";

export default function SearchPage() {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Photo[]>([]);
  const [searched, setSearched] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSearch(e: React.FormEvent) {
    e.preventDefault();
    if (!query.trim()) return;
    setLoading(true);
    setError("");
    try {
      const photos = await searchPhotos(query.trim());
      setResults(photos);
      setSearched(true);
    } catch {
      setError("Search failed. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Search</h2>

      <form onSubmit={handleSearch} className="flex gap-2">
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by detected text..."
          className="max-w-md"
        />
        <Button type="submit" disabled={loading || !query.trim()}>
          {loading ? "Searching..." : "Search"}
        </Button>
      </form>

      {error && <p className="text-sm text-destructive">{error}</p>}

      {loading && (
        <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-1">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="aspect-square" />
          ))}
        </div>
      )}

      {!loading && searched && results.length === 0 && (
        <p className="text-muted-foreground text-center py-10">
          No photos found matching &quot;{query}&quot;
        </p>
      )}

      {!loading && !searched && (
        <p className="text-muted-foreground text-center py-10">
          Search for photos by detected text content
        </p>
      )}

      {!loading && results.length > 0 && (
        <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-1">
          {results.map((photo) => (
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
      )}
    </div>
  );
}
