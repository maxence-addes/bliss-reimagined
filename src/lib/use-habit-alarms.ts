import { useEffect, useRef } from "react";
import { toast } from "sonner";
import { isScheduledOn, todayKey, type Habit } from "./habits";

const playBeep = () => {
  try {
    const Ctx =
      window.AudioContext ??
      (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    const start = ctx.currentTime;
    for (let i = 0; i < 3; i++) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.value = 880;
      const t = start + i * 0.5;
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(0.25, t + 0.05);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.4);
      osc.connect(gain).connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.45);
    }
    setTimeout(() => void ctx.close(), 2500);
  } catch {
    /* ignore */
  }
};

export const requestAlarmPermission = async () => {
  if (typeof window === "undefined" || !("Notification" in window)) return;
  if (Notification.permission === "default") {
    try {
      await Notification.requestPermission();
    } catch {
      /* ignore */
    }
  }
};

/** Déclenche une alarme sonore quand l'heure de l'habitude (moins le délai) arrive. */
export const useHabitAlarms = (habits: Habit[], enabled = true) => {
  const habitsRef = useRef(habits);
  habitsRef.current = habits;
  const fired = useRef<Set<string>>(new Set());

  useEffect(() => {
    if (!enabled || typeof window === "undefined") return;

    const tick = () => {
      const now = new Date();
      const key = todayKey(now);
      const minutesNow = now.getHours() * 60 + now.getMinutes();

      habitsRef.current.forEach((h) => {
        const alarm = h.schedule?.alarm;
        if (!alarm?.time) return;
        if (!isScheduledOn(h, now)) return;
        if (h.completions.includes(key)) return;

        const [hh, mm] = alarm.time.split(":").map(Number);
        if (Number.isNaN(hh) || Number.isNaN(mm)) return;
        const target = hh * 60 + mm - (alarm.leadMinutes || 0);
        if (minutesNow < target || minutesNow > target + 2) return;

        const id = `${h.id}:${key}:${target}`;
        if (fired.current.has(id)) return;
        fired.current.add(id);

        playBeep();
        toast(`⏰ ${h.name}`, {
          description: alarm.leadMinutes
            ? `Dans ${alarm.leadMinutes} min (${alarm.time})`
            : `C'est l'heure (${alarm.time})`,
          duration: 15000,
        });
        if ("Notification" in window && Notification.permission === "granted") {
          try {
            new Notification(`⏰ ${h.name}`, {
              body: alarm.leadMinutes
                ? `Dans ${alarm.leadMinutes} min (${alarm.time})`
                : `C'est l'heure (${alarm.time})`,
            });
          } catch {
            /* ignore */
          }
        }
      });
    };

    tick();
    const interval = window.setInterval(tick, 20000);
    return () => window.clearInterval(interval);
  }, [enabled]);
};
