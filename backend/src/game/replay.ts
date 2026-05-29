import { ReplayEvent } from "./types.js";

export interface ReplayTimelineItem {
  offsetMs: number;
  event: ReplayEvent;
}

export function buildReplayTimeline(events: ReplayEvent[]): ReplayTimelineItem[] {
  if (events.length === 0) return [];
  const start = events[0].at;
  return events.map((event) => ({ offsetMs: event.at - start, event }));
}
