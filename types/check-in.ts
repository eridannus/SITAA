export interface ActivityCheckinToken {
  id: string;
  activity_id: string;
  secret_token: string;
  three_word_code: string;
  is_active?: boolean | null;
  opened_at?: string | null;
  closed_at?: string | null;
}

export interface CheckinActionState {
  status: "idle" | "success" | "already" | "not-participant" | "invalid" | "error";
  message: string | null;
  activityTitle?: string | null;
  attendanceStatus?: string | null;
  checkedInAt?: string | null;
}
