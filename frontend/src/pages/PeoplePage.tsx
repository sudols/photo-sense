import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { listPersons } from "@/api/persons";
import type { Person } from "@/api/types";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";

export default function PeoplePage() {
  const navigate = useNavigate();
  const [persons, setPersons] = useState<Person[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    listPersons()
      .then(setPersons)
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-24" />
        <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="space-y-2">
              <Skeleton className="aspect-square rounded-full" />
              <Skeleton className="h-4 w-20 mx-auto" />
            </div>
          ))}
        </div>
      </div>
    );
  }

  const named = persons.filter((p) => !p.is_unnamed);
  const unnamed = persons.filter((p) => p.is_unnamed);

  if (persons.length === 0) {
    return (
      <div className="text-center py-20">
        <p className="text-muted-foreground">
          No people found. Upload photos with faces to see them clustered
          here.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <h2 className="text-2xl font-bold">People</h2>

      {named.length > 0 && (
        <section>
          <h3 className="text-sm font-medium text-muted-foreground mb-3">
            Named
          </h3>
          <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-4">
            {named.map((person) => (
              <PersonCard
                key={person.id}
                person={person}
                onClick={() => navigate(`/people/${person.id}`)}
              />
            ))}
          </div>
        </section>
      )}

      {unnamed.length > 0 && (
        <section>
          <h3 className="text-sm font-medium text-muted-foreground mb-3">
            Unnamed
          </h3>
          <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-4">
            {unnamed.map((person) => (
              <PersonCard
                key={person.id}
                person={person}
                onClick={() => navigate(`/people/${person.id}`)}
              />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

function PersonCard({
  person,
  onClick,
}: {
  person: Person;
  onClick: () => void;
}) {
  const initials = person.name
    .split(" ")
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <button
      onClick={onClick}
      className="flex flex-col items-center gap-2 hover:opacity-80 transition-opacity focus:outline-none focus:ring-2 focus:ring-ring rounded-lg p-1"
    >
      {person.thumbnail_url ? (
        <img
          src={person.thumbnail_url}
          alt={person.name}
          className="aspect-square w-full object-cover rounded-full"
          loading="lazy"
        />
      ) : (
        <Avatar className="aspect-square w-full">
          <AvatarFallback className="text-lg">{initials}</AvatarFallback>
        </Avatar>
      )}
      <span className="text-xs text-center truncate w-full">
        {person.name}
      </span>
    </button>
  );
}
