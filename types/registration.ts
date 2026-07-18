export type RegistrationPersonType = "student" | "professor";

export interface RegistrationFormValues {
  person_type: RegistrationPersonType | "";
  first_names: string;
  paternal_surname: string;
  maternal_surname: string;
  institutional_id_value: string;
  primary_program_id: string;
}

export type RegistrationField = keyof RegistrationFormValues;

export interface RegistrationState {
  status: "idle" | "error";
  message: string | null;
  fieldErrors: Partial<Record<RegistrationField, string>>;
  values: RegistrationFormValues;
}

export interface RegistrationProgram {
  id: string;
  name: string;
}
