"use client";

import { useActionState } from "react";
import { addActivityParticipant, removeActivityParticipant, searchParticipationProfiles } from "./actions";
import type { ActivityParticipantDisplay, ParticipantSearchState } from "@/types/participants";
import type { ParticipantRole } from "@/types/catalogs";

const idLabels = { student_account: "Número de cuenta", worker_number: "Número de trabajador" } as const;

function RemoveButton({ activityId, participantId }: { activityId: string; participantId: string }) {
  return <form action={removeActivityParticipant.bind(null, activityId, participantId)} onSubmit={(event) => {
    if (!window.confirm("¿Confirmas que deseas retirar a esta persona de la actividad?")) event.preventDefault();
  }}>
    <input type="hidden" name="confirmation" value="confirmed" />
    <button type="submit" className="text-sm font-bold text-red-700 hover:text-red-900">Retirar participante</button>
  </form>;
}

export function ParticipantManager({ activityId, participants, roles, canEdit, status }: {
  activityId: string;
  participants: ActivityParticipantDisplay[];
  roles: ParticipantRole[];
  canEdit: boolean;
  status?: string;
}) {
  const [searchState, searchAction, pending] = useActionState<ParticipantSearchState, FormData>(
    searchParticipationProfiles.bind(null, activityId),
    { query: "", results: [], error: null },
  );
  const statusMessages: Record<string, string> = {
    added: "La persona se agregó correctamente.",
    removed: "La persona se retiró correctamente.",
    duplicate: "La persona seleccionada ya está agregada a esta actividad.",
    invalid: "Selecciona un perfil registrado y un rol de participante válido.",
    forbidden: "No tienes permiso para modificar participantes.",
    error: "No fue posible agregar a la persona. Intenta nuevamente.",
    "remove-error": "No fue posible retirar a la persona.",
  };

  return <section className="mt-10 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
    <div><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Registro institucional</p><h2 className="mt-2 text-2xl font-bold text-slate-900">Participantes</h2><p className="mt-3 text-slate-600">Solo pueden agregarse perfiles registrados en SITAA.</p></div>
    {status && statusMessages[status] && <div role={status.includes("error") || status === "duplicate" || status === "invalid" || status === "forbidden" ? "alert" : "status"} className="mt-6 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-800">{statusMessages[status]}</div>}

    {participants.length ? <div className="mt-7 grid gap-4 md:grid-cols-2">{participants.map((participant) => <article key={participant.id} className="min-w-0 rounded-2xl border border-slate-200 bg-slate-50 p-5">
      <h3 className="break-words font-bold text-slate-900">{participant.full_name}</h3>
      <p className="mt-2 break-all text-sm text-slate-600">{participant.email}</p>
      <dl className="mt-4 space-y-2 text-sm">
        <div className="min-w-0"><dt className="font-semibold text-slate-500">{idLabels[participant.institutional_id_type]}</dt><dd className="break-words text-slate-900">{participant.institutional_id_value}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Programa</dt><dd className="break-words text-slate-900">{participant.program_name}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Rol en la actividad</dt><dd className="break-words text-slate-900">{participant.participant_role_label}</dd></div>
      </dl>
      {canEdit && <div className="mt-4"><RemoveButton activityId={activityId} participantId={participant.id} /></div>}
    </article>)}</div> : <p className="mt-7 rounded-2xl bg-slate-50 p-5 text-slate-600">Aún no hay participantes registrados en esta actividad.</p>}

    {canEdit && <div className="mt-9 border-t border-slate-200 pt-8">
      <h3 className="text-lg font-bold text-slate-900">Agregar participante</h3>
      <form action={searchAction} className="mt-4 flex flex-col gap-3 sm:flex-row">
        <label htmlFor="search_text" className="sr-only">Buscar perfil</label>
        <input id="search_text" name="search_text" defaultValue={searchState.query} required placeholder="Nombre, correo o identificador institucional" className="min-w-0 flex-1 rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
        <button disabled={pending} className="rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white disabled:bg-slate-400">{pending ? "Buscando…" : "Buscar"}</button>
      </form>
      {searchState.error && <p role="alert" className="mt-3 text-sm font-semibold text-red-700">{searchState.error}</p>}
      {searchState.results.length > 0 && <div className="mt-6 grid gap-4">{searchState.results.map((result) => <form key={result.profile_id} action={addActivityParticipant.bind(null, activityId)} className="min-w-0 rounded-2xl border border-slate-200 p-5">
        <input type="hidden" name="profile_id" value={result.profile_id} />
        <div className="grid min-w-0 gap-4 md:grid-cols-[minmax(0,1fr)_minmax(12rem,0.55fr)_auto] md:items-end">
          <div className="min-w-0"><p className="break-words font-bold text-slate-900">{result.full_name}</p><p className="mt-1 break-all text-sm text-slate-600">{result.email}</p><p className="mt-2 break-words text-xs text-slate-500">{idLabels[result.institutional_id_type]}: {result.institutional_id_value} · {result.program_name}</p></div>
          <div className="min-w-0"><label className="text-sm font-semibold text-slate-700">Rol de participante</label><select name="participant_role_code" required defaultValue="" className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-3"><option value="" disabled>Selecciona un rol</option>{roles.map((role) => <option key={role.id} value={role.code}>{role.label?.trim() || role.name?.trim() || role.code}</option>)}</select></div>
          <button type="submit" className="rounded-full border border-emerald-700 px-5 py-3 text-sm font-bold text-emerald-800">Agregar</button>
        </div>
      </form>)}</div>}
      {!searchState.error && searchState.query && searchState.results.length === 0 && <p className="mt-5 text-sm text-slate-600">No se encontraron perfiles registrados.</p>}
    </div>}
  </section>;
}
