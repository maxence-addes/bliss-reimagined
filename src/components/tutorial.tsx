import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import {
  Sparkles,
  ListChecks,
  CalendarDays,
  Camera,
  Users,
  Trophy,
  type LucideIcon,
} from "lucide-react";

export type TutorialStep = {
  icon: LucideIcon;
  title: string;
  body: string;
};

export const TUTORIAL_STEPS: TutorialStep[] = [
  {
    icon: Sparkles,
    title: "Bienvenue sur Daily Rhythms",
    body: "En 5 étapes, découvrez comment construire des habitudes qui tiennent dans le temps. Vous pouvez passer ce tutoriel et le retrouver à tout moment dans le Centre d'aide.",
  },
  {
    icon: ListChecks,
    title: "Créez une habitude",
    body: "Depuis l'accueil, appuyez sur « + ». Donnez un nom, une description facultative, puis validez. Cochez la case chaque jour où vous l'accomplissez.",
  },
  {
    icon: CalendarDays,
    title: "Choisissez la fréquence",
    body: "Quotidienne, hebdomadaire (jours précis), à des dates choisies ou avec une échéance : seules les habitudes prévues aujourd'hui apparaissent sur l'accueil.",
  },
  {
    icon: Camera,
    title: "Preuves et validation",
    body: "Un enfant peut envoyer une photo comme preuve d'une habitude. Le parent lié la retrouve dans « À valider » et l'approuve ou la refuse en un clic.",
  },
  {
    icon: Users,
    title: "Liez un compte",
    body: "Dans « Informations personnelles », copiez votre code d'invitation et partagez-le, ou saisissez celui de l'autre compte pour relier parent et enfant.",
  },
  {
    icon: Trophy,
    title: "Suivez vos séries",
    body: "Chaque journée complétée alimente votre série. Consultez la flamme et les statistiques pour visualiser votre progression semaine après semaine.",
  },
];

export function Tutorial({
  open,
  onOpenChange,
  onFinish,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onFinish?: () => void;
}) {
  const [index, setIndex] = useState(0);
  const step = TUTORIAL_STEPS[index]!;
  const isLast = index === TUTORIAL_STEPS.length - 1;

  const close = () => {
    onOpenChange(false);
    onFinish?.();
    setIndex(0);
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) close();
        else onOpenChange(true);
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center mb-2">
            <step.icon className="w-5 h-5 text-primary" />
          </div>
          <DialogTitle>{step.title}</DialogTitle>
          <DialogDescription className="text-left">{step.body}</DialogDescription>
        </DialogHeader>

        <div className="flex items-center justify-center gap-1.5 py-2">
          {TUTORIAL_STEPS.map((_, i) => (
            <span
              key={i}
              className={
                "h-1.5 rounded-full transition-all " +
                (i === index ? "w-5 bg-primary" : "w-1.5 bg-muted-foreground/30")
              }
            />
          ))}
        </div>

        <div className="flex items-center justify-between gap-3">
          <Button variant="ghost" size="sm" onClick={close}>
            Passer
          </Button>
          <div className="flex items-center gap-2">
            {index > 0 && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => setIndex((i) => i - 1)}
              >
                Précédent
              </Button>
            )}
            <Button
              size="sm"
              onClick={() => (isLast ? close() : setIndex((i) => i + 1))}
            >
              {isLast ? "C'est parti" : "Suivant"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
