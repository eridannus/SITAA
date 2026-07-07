import type { DurationMode } from "@/types/activities";

const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;

export function isValidDate(value: string) {
  if (!datePattern.test(value)) {
    return false;
  }

  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

export function isValidTime(value: string) {
  return timePattern.test(value);
}

export function getMexicoCityToday() {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Mexico_City",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export function addHoursToLocalDateTime(dateValue: string, timeValue: string, hours: number) {
  if (!isValidDate(dateValue) || !isValidTime(timeValue)) {
    return null;
  }

  const [year, month, day] = dateValue.split("-").map(Number);
  const [hour, minute] = timeValue.split(":").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, hour + hours, minute));

  return {
    endDate: [
      date.getUTCFullYear(),
      String(date.getUTCMonth() + 1).padStart(2, "0"),
      String(date.getUTCDate()).padStart(2, "0"),
    ].join("-"),
    endTime: [
      String(date.getUTCHours()).padStart(2, "0"),
      String(date.getUTCMinutes()).padStart(2, "0"),
    ].join(":"),
  };
}

export function calculatePresetEnd(
  dateValue: string,
  timeValue: string,
  durationMode: DurationMode,
) {
  if (durationMode === "one_hour") {
    return addHoursToLocalDateTime(dateValue, timeValue, 1);
  }

  if (durationMode === "two_hours") {
    return addHoursToLocalDateTime(dateValue, timeValue, 2);
  }

  return null;
}

export function toMexicoCityTimestamp(dateValue: string, timeValue: string) {
  return `${dateValue}T${timeValue}:00-06:00`;
}