"use client";
import { deleteActivity } from "@/app/activities/actions";

export function DeleteActivityButton({ activityId }: { activityId: string }) {
  return (
    <form action={deleteActivity.bind(null, activityId)} onSubmit={(event) => {
      if (!window.confirm("¿Confirmas que deseas eliminar esta actividad? Esta acción no se puede deshacer.")) event.preventDefault();
    }}>
      <input type="hidden" name="confirmation" value="confirmed" />
      <button type="submit" className="sitaa-destructive-action px-6">Eliminar actividad</button>
    </form>
  );
}
