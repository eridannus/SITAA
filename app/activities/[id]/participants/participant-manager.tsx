"use client";

import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { addActivityParticipant, removeActivityParticipant, searchParticipationProfiles, updateParticipantAttendance, updateParticipantsAttendanceBulk } from "./actions";
import type { ActivityParticipantDisplay, AttendanceSource, AttendanceStatus, ParticipantMutationState, ParticipantSearchState, ParticipationProfileSearchResult } from "@/types/participants";
import type { ParticipantRole } from "@/types/catalogs";

const idLabels = { student_account: "Número de cuenta", worker_number: "Número de trabajador" } as const;
const attendanceStatusLabels: Record<AttendanceStatus, string> = {
  pending: "Pendiente",
  attended: "Asistió",
  absent: "No asistió",
  justified: "Justificada",
};
const attendanceSourceLabels: Record<AttendanceSource, string> = {
  system: "Sistema",
  manual: "Manual",
  qr: "QR o enlace",
  code: "Código",
};

function normalizeText(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function roleText(role: ParticipantRole) {
  return normalizeText([role.code, role.label, role.name].filter(Boolean).join(" "));
}

function roleLabel(role: ParticipantRole) {
  return role.label?.trim() || role.name?.trim() || role.code;
}

function isResponsibleRole(role: ParticipantRole) {
  return /responsable|responsible/.test(roleText(role));
}

function isPeerTutorRole(role: ParticipantRole) {
  return /tutor par|peer/.test(roleText(role));
}

function isStudentParticipantRole(role: ParticipantRole) {
  return /alumno|student|participante|participant/.test(roleText(role));
}

function isSupportRole(role: ParticipantRole) {
  return /apoyo|support/.test(roleText(role));
}

function isGuestRole(role: ParticipantRole) {
  return /invitado|guest/.test(roleText(role));
}

function rolesForPersonType(roles: ParticipantRole[], personType: string) {
  if (personType === "student") return roles.filter((role) => !isResponsibleRole(role));

  if (personType === "worker") {
    const workerRoles = roles.filter((role) => isResponsibleRole(role) || isSupportRole(role) || isGuestRole(role));
    return workerRoles.length ? workerRoles : roles.filter((role) => !isStudentParticipantRole(role) && !isPeerTutorRole(role));
  }

  return roles;
}

const bulkActions: Array<{ status: AttendanceStatus; label: string }> = [
  { status: "attended", label: "Marcar como Asistió" },
  { status: "absent", label: "Marcar como No asistió" },
  { status: "pending", label: "Marcar como Pendiente" },
  { status: "justified", label: "Marcar como Justificada" },
];

function formatDateTime(value: string | null) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("es-MX", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "America/Mexico_City",
  }).format(date);
}

function AddButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} aria-disabled={pending} className="rounded-full border border-emerald-700 px-5 py-3 text-sm font-bold text-emerald-800 disabled:cursor-not-allowed disabled:border-slate-300 disabled:text-slate-500 cursor-pointer disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 transition hover:opacity-90">
    {pending ? "Agregando…" : "Agregar"}
  </button>;
}

function AttendanceButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} aria-disabled={pending} className="rounded-full bg-emerald-800 px-5 py-3 text-sm font-bold text-white disabled:cursor-not-allowed disabled:bg-slate-400 cursor-pointer disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 transition hover:opacity-90">
    {pending ? "Guardando…" : "Guardar asistencia"}
  </button>;
}

function BulkButton({ status, label, disabled }: { status: AttendanceStatus; label: string; disabled: boolean }) {
  const { pending } = useFormStatus();
  const isDisabled = pending || disabled;
  return <button type="submit" name="attendance_status" value={status} disabled={isDisabled} aria-disabled={isDisabled} className="rounded-full border border-slate-300 px-4 py-2 text-sm font-bold text-slate-800 transition hover:border-emerald-700 hover:text-emerald-800 disabled:cursor-not-allowed disabled:border-slate-200 disabled:text-slate-400 disabled:opacity-60 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
    {pending ? "Actualizando…" : label}
  </button>;
}

function RemoveButton({ activityId, participantId }: { activityId: string; participantId: string }) {
  return <form action={removeActivityParticipant.bind(null, activityId, participantId)} onSubmit={(event) => {
    if (!window.confirm("¿Confirmas que deseas retirar a esta persona de la actividad?")) event.preventDefault();
  }}>
    <input type="hidden" name="confirmation" value="confirmed" />
    <RemoveSubmitButton />
  </form>;
}
function RemoveSubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} className="text-sm font-bold text-red-700 disabled:cursor-not-allowed disabled:text-slate-400 hover:text-red-900 cursor-pointer disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-600 focus-visible:ring-offset-2">{pending ? "Eliminando…" : "Retirar participante"}</button>;
}

function AttendanceForm({ activityId, participant }: { activityId: string; participant: ActivityParticipantDisplay }) {
  const [state, action] = useActionState<ParticipantMutationState, FormData>(
    updateParticipantAttendance.bind(null, activityId, participant.id),
    { error: null },
  );

  return <form action={action} className="mt-5 rounded-2xl border border-slate-200 bg-white p-4">
    <div className="grid gap-4">
      <div>
        <label htmlFor={`attendance-status-${participant.id}`} className="block text-sm font-semibold text-slate-700">Estado de asistencia</label>
        <select id={`attendance-status-${participant.id}`} name="attendance_status" defaultValue={participant.attendance_status ?? "pending"} className="mt-2 w-full rounded-xl border border-slate-300 bg-white px-3 py-3 text-sm">
          {Object.entries(attendanceStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
      </div>
      <div>
        <label htmlFor={`attendance-notes-${participant.id}`} className="block text-sm font-semibold text-slate-700">Notas de asistencia</label>
        <textarea id={`attendance-notes-${participant.id}`} name="attendance_notes" defaultValue={participant.attendance_notes ?? ""} rows={3} maxLength={1000} placeholder="Opcional" className="mt-2 w-full rounded-xl border border-slate-300 px-3 py-3 text-sm outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
      </div>
    </div>
    <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <AttendanceButton />
      {state.error && <p role="alert" className="text-sm font-semibold text-red-700">{state.error}</p>}
    </div>
  </form>;
}

function AddParticipantForm({ activityId, result, roles }: {
  activityId: string;
  result: ParticipationProfileSearchResult;
  roles: ParticipantRole[];
}) {
  const availableRoles = rolesForPersonType(roles, result.person_type);
  const [roleCode, setRoleCode] = useState("");
  const [state, action] = useActionState<ParticipantMutationState, FormData>(
    addActivityParticipant.bind(null, activityId),
    { error: null },
  );
  return <form action={action} className="min-w-0 rounded-2xl border border-slate-200 p-5">
    <input type="hidden" name="profile_id" value={result.profile_id} />
    <input type="hidden" name="participant_primary_program_id" value={result.primary_program_id ?? ""} />
    <input type="hidden" name="participant_person_type" value={result.person_type} />
    <div className="grid min-w-0 gap-4 md:grid-cols-[minmax(0,1fr)_minmax(12rem,0.55fr)_auto] md:items-end">
      <div className="min-w-0"><p className="break-words font-bold text-slate-900">{result.full_name}</p><p className="mt-1 break-all text-sm text-slate-600">{result.email}</p><p className="mt-2 break-words text-xs text-slate-500">{idLabels[result.institutional_id_type]}: {result.institutional_id_value} · {result.program_name}</p></div>
      <div className="min-w-0">
        <label htmlFor={`participant-role-${result.profile_id}`} className="text-sm font-semibold text-slate-700">Rol de participante</label>
        <select id={`participant-role-${result.profile_id}`} name="participant_role_code" required value={roleCode} onChange={(event) => setRoleCode(event.target.value)} className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-3">
          <option value="" disabled>Selecciona un rol</option>
          {availableRoles.map((role) => <option key={role.id} value={role.code}>{roleLabel(role)}</option>)}
        </select>
      </div>
      <AddButton />
    </div>
    {state.error && <p role="alert" className="mt-4 text-sm font-semibold text-red-700">{state.error}</p>}
  </form>;
}

function AttendanceListView({ activityId, participants }: { activityId: string; participants: ActivityParticipantDisplay[] }) {
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [state, action] = useActionState<ParticipantMutationState, FormData>(
    updateParticipantsAttendanceBulk.bind(null, activityId),
    { error: null },
  );
  const selected = new Set(selectedIds);
  const allSelected = participants.length > 0 && selectedIds.length === participants.length;

  function toggleParticipant(id: string) {
    setSelectedIds((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }

  return <div className="mt-7 rounded-2xl border border-slate-200 bg-slate-50 p-4">
    <div className="flex flex-col gap-3 border-b border-slate-200 pb-4 lg:flex-row lg:items-center lg:justify-between">
      <div className="flex flex-wrap items-center gap-2">
        <button type="button" onClick={() => setSelectedIds(participants.map((participant) => participant.id))} disabled={!participants.length || allSelected} className="rounded-full border border-slate-300 px-4 py-2 text-sm font-bold text-slate-800 transition hover:border-emerald-700 hover:text-emerald-800 disabled:cursor-not-allowed disabled:text-slate-400 disabled:opacity-60 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Seleccionar todos</button>
        <button type="button" onClick={() => setSelectedIds([])} disabled={!selectedIds.length} className="rounded-full border border-slate-300 px-4 py-2 text-sm font-bold text-slate-800 transition hover:border-emerald-700 hover:text-emerald-800 disabled:cursor-not-allowed disabled:text-slate-400 disabled:opacity-60 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Limpiar selección</button>
        <p className="text-sm font-semibold text-slate-600">{selectedIds.length} seleccionado{selectedIds.length === 1 ? "" : "s"}</p>
      </div>
      {!selectedIds.length && <p className="text-sm text-slate-500">Selecciona al menos un participante.</p>}
    </div>

    <form action={action} className="mt-4">
      {selectedIds.map((id) => <input key={id} type="hidden" name="participant_ids" value={id} />)}
      <div className="flex flex-wrap gap-2">
        {bulkActions.map((item) => <BulkButton key={item.status} status={item.status} label={item.label} disabled={!selectedIds.length} />)}
      </div>
      {state.error && <p role="alert" className="mt-3 text-sm font-semibold text-red-700">{state.error}</p>}
    </form>

    <div className="mt-5 overflow-x-auto rounded-2xl border border-slate-200 bg-white">
      <table className="min-w-full divide-y divide-slate-200 text-sm">
        <thead className="bg-slate-50 text-left text-xs font-bold uppercase tracking-wide text-slate-500">
          <tr>
            <th className="w-12 px-4 py-3"><span className="sr-only">Seleccionar</span></th>
            <th className="px-4 py-3">Identificador</th>
            <th className="px-4 py-3">Nombre completo</th>
            <th className="px-4 py-3">Rol</th>
            <th className="px-4 py-3">Asistencia</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {participants.map((participant) => (
            <tr key={participant.id} className={selected.has(participant.id) ? "bg-emerald-50" : "bg-white"}>
              <td className="px-4 py-3 align-top">
                <input type="checkbox" checked={selected.has(participant.id)} onChange={() => toggleParticipant(participant.id)} aria-label={`Seleccionar a ${participant.full_name}`} className="h-4 w-4 cursor-pointer rounded border-slate-300 text-emerald-700 focus:ring-emerald-600" />
              </td>
              <td className="max-w-[10rem] px-4 py-3 align-top"><span className="block break-words font-semibold text-slate-900">{participant.institutional_id_value}</span><span className="block break-words text-xs text-slate-500">{idLabels[participant.institutional_id_type]}</span></td>
              <td className="min-w-[14rem] max-w-[22rem] px-4 py-3 align-top"><span className="block break-words font-semibold text-slate-900">{participant.full_name}</span><span className="block break-all text-xs text-slate-500">{participant.email}</span></td>
              <td className="max-w-[12rem] px-4 py-3 align-top break-words text-slate-700">{participant.participant_role_label}</td>
              <td className="max-w-[10rem] px-4 py-3 align-top break-words font-semibold text-slate-900">{attendanceStatusLabels[participant.attendance_status ?? "pending"]}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  </div>;
}

export function ParticipantManager({ activityId, participants, roles, canEdit, status }: {
  activityId: string;
  participants: ActivityParticipantDisplay[];
  roles: ParticipantRole[];
  canEdit: boolean;
  status?: string;
}) {
  const [viewMode, setViewMode] = useState<"detail" | "attendance">("detail");
  const [searchState, searchAction, searchPending] = useActionState<ParticipantSearchState, FormData>(
    searchParticipationProfiles.bind(null, activityId),
    { query: "", results: [], error: null },
  );
  const attendanceSummary = {
    registered: participants.length,
    attended: participants.filter((participant) => participant.attendance_status === "attended").length,
    absent: participants.filter((participant) => participant.attendance_status === "absent").length,
  };
  const summaryCards = [
    { label: "Registrados", value: attendanceSummary.registered },
    { label: "Asistieron", value: attendanceSummary.attended },
    { label: "Faltaron", value: attendanceSummary.absent },
  ];
  const statusMessages: Record<string, string> = {
    added: "Participante agregado correctamente.",
    removed: "Participante eliminado correctamente.",
    duplicate: "Esta persona ya está registrada en la actividad.",
    invalid: "Selecciona un perfil registrado y un rol de participante válido.",
    forbidden: "No tienes permiso para agregar participantes a esta actividad.",
    error: "No fue posible agregar a la persona. Intenta nuevamente.",
    "remove-error": "No fue posible eliminar al participante.",
    "remove-forbidden": "No tienes permiso para eliminar participantes de esta actividad.",
    "attendance-updated": "Asistencia actualizada correctamente.",
  };

  return <section id="participants" className="mt-10 scroll-mt-24 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
    <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
      <div className="min-w-0"><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Registro institucional</p><h2 className="mt-2 text-2xl font-bold text-slate-900">Participantes</h2><p className="mt-3 text-slate-600">S?lo pueden agregarse perfiles registrados en SITAA.</p></div>
      {canEdit && <div className="grid gap-3 sm:grid-cols-3 lg:min-w-[24rem]">
        {summaryCards.map((item) => <div key={item.label} className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3">
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-slate-500">{item.label}</p>
          <p className="mt-2 text-3xl font-bold text-slate-900">{item.value}</p>
        </div>)}
      </div>}
    </div>
    {status && statusMessages[status] && <div role={status.includes("error") || status.includes("forbidden") || status === "duplicate" || status === "invalid" ? "alert" : "status"} className="mt-6 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-800">{statusMessages[status]}</div>}

    {canEdit && participants.length > 0 && <div className="mt-7 inline-flex rounded-full border border-slate-200 bg-slate-50 p-1">
      <button type="button" onClick={() => setViewMode("detail")} className={`cursor-pointer rounded-full px-4 py-2 text-sm font-bold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 ${viewMode === "detail" ? "bg-white text-emerald-900 shadow-sm" : "text-slate-600 hover:text-slate-900"}`}>Detalle</button>
      <button type="button" onClick={() => setViewMode("attendance")} className={`cursor-pointer rounded-full px-4 py-2 text-sm font-bold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 ${viewMode === "attendance" ? "bg-white text-emerald-900 shadow-sm" : "text-slate-600 hover:text-slate-900"}`}>Pase de lista</button>
    </div>}

    {participants.length ? (viewMode === "attendance" && canEdit ? <AttendanceListView activityId={activityId} participants={participants} /> : <div className="mt-7 grid gap-4 md:grid-cols-2">{participants.map((participant) => {
      const updatedAt = formatDateTime(participant.attendance_updated_at);
      return <article key={participant.id} className="min-w-0 rounded-2xl border border-slate-200 bg-slate-50 p-5">
        <h3 className="break-words font-bold text-slate-900">{participant.full_name}</h3>
        <p className="mt-2 break-all text-sm text-slate-600">{participant.email}</p>
        <dl className="mt-4 space-y-2 text-sm">
          <div className="min-w-0"><dt className="font-semibold text-slate-500">{idLabels[participant.institutional_id_type]}</dt><dd className="break-words text-slate-900">{participant.institutional_id_value}</dd></div>
          <div className="min-w-0"><dt className="font-semibold text-slate-500">Programa</dt><dd className="break-words text-slate-900">{participant.program_name}</dd></div>
          <div className="min-w-0"><dt className="font-semibold text-slate-500">Rol en la actividad</dt><dd className="break-words text-slate-900">{participant.participant_role_label}</dd></div>
          <div className="min-w-0"><dt className="font-semibold text-slate-500">Asistencia</dt><dd className="break-words text-slate-900">{attendanceStatusLabels[participant.attendance_status ?? "pending"]}</dd></div>
          <div className="min-w-0"><dt className="font-semibold text-slate-500">Fuente</dt><dd className="break-words text-slate-900">{attendanceSourceLabels[participant.attendance_source ?? "system"]}</dd></div>
          {updatedAt && <div className="min-w-0"><dt className="font-semibold text-slate-500">Actualización</dt><dd className="break-words text-slate-900">{updatedAt}</dd></div>}
          {participant.attendance_notes && <div className="min-w-0"><dt className="font-semibold text-slate-500">Notas</dt><dd className="break-words text-slate-900">{participant.attendance_notes}</dd></div>}
        </dl>
        {canEdit && <AttendanceForm activityId={activityId} participant={participant} />}
        {canEdit && <div className="mt-4"><RemoveButton activityId={activityId} participantId={participant.id} /></div>}
      </article>;
    })}</div>) : <p className="mt-7 rounded-2xl bg-slate-50 p-5 text-slate-600">Aún no hay participantes registrados en esta actividad.</p>}

    {canEdit && <div className="mt-9 border-t border-slate-200 pt-8">
      <h3 className="text-lg font-bold text-slate-900">Agregar participante</h3>
      <form action={searchAction} className="mt-4 flex flex-col gap-3 sm:flex-row">
        <label htmlFor="search_text" className="sr-only">Buscar perfil</label>
        <input id="search_text" name="search_text" defaultValue={searchState.query} required placeholder="Nombre, correo o identificador institucional" className="min-w-0 flex-1 rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
        <button type="submit" disabled={searchPending} aria-disabled={searchPending} className="rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white disabled:cursor-not-allowed disabled:bg-slate-400 cursor-pointer disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 transition hover:opacity-90">{searchPending ? "Buscando…" : "Buscar"}</button>
      </form>
      {searchState.error && <p role="alert" className="mt-3 text-sm font-semibold text-red-700">{searchState.error}</p>}
      {searchState.results.length > 0 && <div className="mt-6 grid gap-4">{searchState.results.map((result) => <AddParticipantForm key={result.profile_id} activityId={activityId} result={result} roles={roles} />)}</div>}
      {!searchState.error && searchState.query && searchState.results.length === 0 && <p className="mt-5 text-sm text-slate-600">No se encontraron perfiles registrados.</p>}
    </div>}
  </section>;
}
