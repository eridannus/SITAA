export type RegistrationPersonType = "student" | "professor";

export interface RegistrationFormValues {
  full_name: string;
  email: string;
  institutional_id_value: string;
  primary_program_id: string;
}

export type RegistrationField =
  | keyof RegistrationFormValues
  | "password"
  | "password_confirmation";

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
