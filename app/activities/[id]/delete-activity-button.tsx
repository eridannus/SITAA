"use client";
import { deleteActivity } from "@/app/activities/actions";

export function DeleteActivityButton({ activityId }: { activityId: string }) {
  return (
    <form action={deleteActivity.bind(null, activityId)} onSubmit={(event) => {
      if (!window.confirm("¿Confirmas que deseas eliminar esta actividad? Esta acción no se puede deshacer.")) event.preventDefault();
    }}>
      <input type="hidden" name="confirmation" value="confirmed" />
      <button type="submit" className="rounded-full bg-red-700 px-6 py-3 text-sm font-bold text-white transition hover:bg-red-800 cursor-pointer disabled:cursor-not-allowed disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-600 focus-visible:ring-offset-2">Eliminar actividad</button>
    </form>
  );
}
