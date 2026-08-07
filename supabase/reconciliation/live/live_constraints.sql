-- table	constraint	type	definition
academic_periods	academic_periods_code_key	unique	UNIQUE (code)
academic_periods	academic_periods_pkey	primary_key	PRIMARY KEY (id)
academic_programs	academic_programs_code_key	unique	UNIQUE (code)
academic_programs	academic_programs_division_id_fkey	foreign_key	FOREIGN KEY (division_id) REFERENCES divisions(id) ON DELETE CASCADE
academic_programs	academic_programs_pkey	primary_key	PRIMARY KEY (id)
activities	activities_academic_period_id_fkey	foreign_key	FOREIGN KEY (academic_period_id) REFERENCES academic_periods(id)
activities	activities_activity_type_code_fkey	foreign_key	FOREIGN KEY (activity_type_code) REFERENCES activity_types(code)
activities	activities_attention_category_code_fkey	foreign_key	FOREIGN KEY (attention_category_code) REFERENCES attention_categories(code)
activities	activities_created_by_fkey	foreign_key	FOREIGN KEY (created_by) REFERENCES auth.users(id)
activities	activities_division_id_fkey	foreign_key	FOREIGN KEY (division_id) REFERENCES divisions(id)
activities	activities_duration_mode_check	check	CHECK (duration_mode IS NULL OR (duration_mode = ANY (ARRAY['one_hour'::text, 'two_hours'::text, 'custom'::text])))
activities	activities_location_type_code_fkey	foreign_key	FOREIGN KEY (location_type_code) REFERENCES location_types(code)
activities	activities_modality_code_fkey	foreign_key	FOREIGN KEY (modality_code) REFERENCES activity_modalities(code)
activities	activities_pkey	primary_key	PRIMARY KEY (id)
activities	activities_program_id_fkey	foreign_key	FOREIGN KEY (program_id) REFERENCES academic_programs(id)
activities	activities_responsible_profile_id_fkey	foreign_key	FOREIGN KEY (responsible_profile_id) REFERENCES profiles(id)
activities	activities_scope_consistency_check	check	CHECK (scope_type = 'program'::text AND program_id IS NOT NULL AND division_id IS NOT NULL OR scope_type = 'division'::text AND division_id IS NOT NULL AND program_id IS NULL)
activities	activities_scope_type_check	check	CHECK (scope_type = ANY (ARRAY['program'::text, 'division'::text]))
activities	activities_service_type_code_fkey	foreign_key	FOREIGN KEY (service_type_code) REFERENCES service_types(code)
activities	activities_status_code_fkey	foreign_key	FOREIGN KEY (status_code) REFERENCES activity_statuses(code)
activities	activities_time_order_check	check	CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)
activities	activities_updated_by_fkey	foreign_key	FOREIGN KEY (updated_by) REFERENCES auth.users(id)
activity_checkin_tokens	activity_checkin_tokens_activity_id_fkey	foreign_key	FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
activity_checkin_tokens	activity_checkin_tokens_created_by_fkey	foreign_key	FOREIGN KEY (created_by) REFERENCES auth.users(id)
activity_checkin_tokens	activity_checkin_tokens_pkey	primary_key	PRIMARY KEY (id)
activity_checkin_tokens	activity_checkin_tokens_type_check	check	CHECK (token_type = ANY (ARRAY['attendance'::text, 'registration'::text]))
activity_modalities	activity_modalities_pkey	primary_key	PRIMARY KEY (code)
activity_participants	activity_participants_activity_id_fkey	foreign_key	FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
activity_participants	activity_participants_added_by_fkey	foreign_key	FOREIGN KEY (added_by) REFERENCES auth.users(id)
activity_participants	activity_participants_attendance_source_check	check	CHECK (attendance_source = ANY (ARRAY['system'::text, 'manual'::text, 'qr'::text, 'code'::text]))
activity_participants	activity_participants_attendance_status_check	check	CHECK (attendance_status = ANY (ARRAY['pending'::text, 'attended'::text, 'absent'::text, 'justified'::text]))
activity_participants	activity_participants_attendance_updated_by_fkey	foreign_key	FOREIGN KEY (attendance_updated_by) REFERENCES auth.users(id)
activity_participants	activity_participants_participant_role_code_fkey	foreign_key	FOREIGN KEY (participant_role_code) REFERENCES participant_roles(code)
activity_participants	activity_participants_pkey	primary_key	PRIMARY KEY (id)
activity_participants	activity_participants_profile_id_fkey	foreign_key	FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
activity_participants	activity_participants_unique_profile_per_activity	unique	UNIQUE (activity_id, profile_id)
activity_statuses	activity_statuses_pkey	primary_key	PRIMARY KEY (code)
activity_types	activity_types_pkey	primary_key	PRIMARY KEY (code)
admin_audit_events	admin_audit_events_action_code_check	check	CHECK (char_length(action_code) >= 1 AND char_length(action_code) <= 100 AND action_code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'::text)
admin_audit_events	admin_audit_events_actor_profile_id_fkey	foreign_key	FOREIGN KEY (actor_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
admin_audit_events	admin_audit_events_metadata_check	check	CHECK (admin_audit_metadata_is_safe(metadata))
admin_audit_events	admin_audit_events_outcome_check	check	CHECK (outcome = ANY (ARRAY['success'::text, 'failure'::text]))
admin_audit_events	admin_audit_events_pkey	primary_key	PRIMARY KEY (id)
admin_audit_events	admin_audit_events_reason_check	check	CHECK (reason IS NULL OR reason = btrim(reason) AND char_length(reason) >= 1 AND char_length(reason) <= 1000)
admin_audit_events	admin_audit_events_role_assignment_id_fkey	foreign_key	FOREIGN KEY (role_assignment_id) REFERENCES role_assignments(id) ON DELETE RESTRICT
admin_audit_events	admin_audit_events_target_profile_id_fkey	foreign_key	FOREIGN KEY (target_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
admin_auth_operations	admin_auth_operations_attempt_check	check	CHECK (attempt_count >= 0)
admin_auth_operations	admin_auth_operations_auth_audit_event_id_fkey	foreign_key	FOREIGN KEY (auth_audit_event_id) REFERENCES admin_audit_events(id) ON DELETE RESTRICT
admin_auth_operations	admin_auth_operations_completed_by_profile_id_fkey	foreign_key	FOREIGN KEY (completed_by_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
admin_auth_operations	admin_auth_operations_error_check	check	CHECK (last_error_code IS NULL OR (last_error_code = ANY (ARRAY['auth_temporarily_unavailable'::text, 'auth_rate_limited'::text, 'auth_user_not_found'::text, 'auth_update_rejected'::text, 'unsupported_auth_contract'::text, 'database_finalize_pending'::text])))
admin_auth_operations	admin_auth_operations_evidence_check	check	CHECK ((operation_code = 'deactivate'::text AND profile_audit_event_id IS NOT NULL OR operation_code = 'reactivate'::text AND (completed_stage <> 'completed'::text AND profile_audit_event_id IS NULL OR completed_stage = 'completed'::text AND profile_audit_event_id IS NOT NULL)) AND (completed_stage = ANY (ARRAY['auth_synchronized'::text, 'completed'::text])) = (auth_synchronized_at IS NOT NULL) AND (status = ANY (ARRAY['succeeded'::text, 'terminal_failure'::text])) = (completed_at IS NOT NULL) AND (status = ANY (ARRAY['succeeded'::text, 'terminal_failure'::text])) = (completed_by_profile_id IS NOT NULL) AND (status = 'succeeded'::text AND completed_stage = 'completed'::text OR status <> 'succeeded'::text AND completed_stage <> 'completed'::text) AND (auth_audit_event_id IS NOT NULL) = ((completed_stage = ANY (ARRAY['auth_synchronized'::text, 'completed'::text])) OR status = 'terminal_failure'::text) AND (status = 'succeeded'::text AND last_error_code IS NULL OR status = 'terminal_failure'::text AND last_error_code IS NOT NULL OR (status = ANY (ARRAY['open'::text, 'processing'::text])) AND last_error_code IS NULL OR status = 'retryable_failure'::text AND last_error_code IS NOT NULL) AND ((status = ANY (ARRAY['open'::text, 'processing'::text])) AND (operation_code = 'reactivate'::text AND (completed_stage = ANY (ARRAY['prepared'::text, 'auth_synchronized'::text])) OR operation_code = 'deactivate'::text AND completed_stage = 'profile_suspended'::text) OR status = 'retryable_failure'::text AND (completed_stage =
CASE
    WHEN operation_code = 'reactivate'::text THEN 'prepared'::text
    ELSE 'profile_suspended'::text
END AND auth_synchronized_at IS NULL AND (last_error_code = ANY (ARRAY['auth_temporarily_unavailable'::text, 'auth_rate_limited'::text, 'auth_user_not_found'::text, 'auth_update_rejected'::text, 'unsupported_auth_contract'::text])) OR operation_code = 'reactivate'::text AND completed_stage = 'auth_synchronized'::text AND auth_audit_event_id IS NOT NULL AND auth_synchronized_at IS NOT NULL AND last_error_code = 'database_finalize_pending'::text) OR status = 'terminal_failure'::text AND completed_stage =
CASE
    WHEN operation_code = 'reactivate'::text THEN 'prepared'::text
    ELSE 'profile_suspended'::text
END AND auth_synchronized_at IS NULL AND (last_error_code = ANY (ARRAY['auth_user_not_found'::text, 'auth_update_rejected'::text, 'unsupported_auth_contract'::text])) OR status = 'succeeded'::text AND completed_stage = 'completed'::text))
admin_auth_operations	admin_auth_operations_operation_check	check	CHECK (operation_code = ANY (ARRAY['deactivate'::text, 'reactivate'::text]))
admin_auth_operations	admin_auth_operations_pkey	primary_key	PRIMARY KEY (id)
admin_auth_operations	admin_auth_operations_profile_audit_event_id_fkey	foreign_key	FOREIGN KEY (profile_audit_event_id) REFERENCES admin_audit_events(id) ON DELETE RESTRICT
admin_auth_operations	admin_auth_operations_reason_check	check	CHECK (reason = btrim(regexp_replace(reason, '\s+'::text, ' '::text, 'g'::text)) AND char_length(reason) >= 10 AND char_length(reason) <= 1000)
admin_auth_operations	admin_auth_operations_request_id_key	unique	UNIQUE (request_id)
admin_auth_operations	admin_auth_operations_requested_by_profile_id_fkey	foreign_key	FOREIGN KEY (requested_by_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
admin_auth_operations	admin_auth_operations_stage_check	check	CHECK (completed_stage = ANY (ARRAY['prepared'::text, 'profile_suspended'::text, 'auth_synchronized'::text, 'completed'::text]))
admin_auth_operations	admin_auth_operations_stage_operation_check	check	CHECK (requested_by_profile_id <> target_profile_id AND (operation_code = 'reactivate'::text AND (completed_stage = ANY (ARRAY['prepared'::text, 'auth_synchronized'::text, 'completed'::text])) OR operation_code = 'deactivate'::text AND (completed_stage = ANY (ARRAY['profile_suspended'::text, 'auth_synchronized'::text, 'completed'::text]))))
admin_auth_operations	admin_auth_operations_status_check	check	CHECK (status = ANY (ARRAY['open'::text, 'processing'::text, 'retryable_failure'::text, 'succeeded'::text, 'terminal_failure'::text]))
admin_auth_operations	admin_auth_operations_target_profile_id_fkey	foreign_key	FOREIGN KEY (target_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
admin_auth_operations	admin_auth_operations_timestamp_check	check	CHECK (updated_at >= requested_at AND (processing_started_at IS NULL OR processing_started_at >= requested_at) AND (auth_synchronized_at IS NULL OR auth_synchronized_at >= requested_at) AND (completed_at IS NULL OR completed_at >= requested_at) AND (auth_synchronized_at IS NULL OR completed_at IS NULL OR completed_at >= auth_synchronized_at) AND (status = 'open'::text AND processing_started_at IS NULL AND last_error_code IS NULL OR status = 'processing'::text AND processing_started_at IS NOT NULL AND last_error_code IS NULL OR status = 'retryable_failure'::text AND processing_started_at IS NOT NULL AND last_error_code IS NOT NULL OR status = 'succeeded'::text AND processing_started_at IS NOT NULL OR status = 'terminal_failure'::text AND processing_started_at IS NOT NULL AND last_error_code IS NOT NULL))
attention_categories	attention_categories_pkey	primary_key	PRIMARY KEY (code)
divisions	divisions_code_key	unique	UNIQUE (code)
divisions	divisions_pkey	primary_key	PRIMARY KEY (id)
location_types	location_types_pkey	primary_key	PRIMARY KEY (code)
participant_roles	participant_roles_pkey	primary_key	PRIMARY KEY (code)
profiles	profiles_account_identity_check	check	CHECK (account_kind = 'institutional'::text AND account_status = 'pending_registration'::text AND person_type IS NULL AND primary_program_id IS NULL AND institutional_id_type IS NULL AND institutional_id_value IS NULL AND first_names IS NULL AND paternal_surname IS NULL AND maternal_surname IS NULL OR account_kind = 'institutional'::text AND (account_status = ANY (ARRAY['active'::text, 'inactive'::text])) AND (person_type = ANY (ARRAY['student'::text, 'professor'::text])) AND primary_program_id IS NOT NULL AND institutional_id_type IS NOT NULL AND institutional_id_value IS NOT NULL AND first_names IS NOT NULL AND paternal_surname IS NOT NULL AND full_name IS NOT NULL AND (person_type = 'student'::text AND institutional_id_type = 'student_account'::text OR person_type = 'professor'::text AND institutional_id_type = 'worker_number'::text) OR account_kind = 'technical'::text AND (account_status = ANY (ARRAY['active'::text, 'inactive'::text])) AND person_type IS NULL AND primary_program_id IS NULL AND institutional_id_type IS NULL AND institutional_id_value IS NULL AND first_names IS NOT NULL AND full_name IS NOT NULL)
profiles	profiles_account_kind_check	check	CHECK (account_kind = ANY (ARRAY['institutional'::text, 'technical'::text]))
profiles	profiles_account_lifecycle_check	check	CHECK (account_status = 'active'::text AND is_active AND activated_at IS NOT NULL AND deactivated_at IS NULL OR account_status = 'pending_registration'::text AND NOT is_active AND activated_at IS NULL AND deactivated_at IS NULL OR account_status = 'inactive'::text AND NOT is_active AND deactivated_at IS NOT NULL)
profiles	profiles_account_status_check	check	CHECK (account_status = ANY (ARRAY['pending_registration'::text, 'active'::text, 'inactive'::text]))
profiles	profiles_email_check	check	CHECK (char_length(email) >= 1 AND char_length(email) <= 254 AND email = lower(btrim(email)))
profiles	profiles_first_names_check	check	CHECK (first_names IS NULL OR char_length(first_names) >= 1 AND char_length(first_names) <= 150 AND first_names = regexp_replace(btrim(first_names), '\s+'::text, ' '::text, 'g'::text))
profiles	profiles_full_name_check	check	CHECK (full_name IS NULL OR char_length(full_name) >= 2 AND char_length(full_name) <= 200 AND full_name = regexp_replace(btrim(full_name), '\s+'::text, ' '::text, 'g'::text))
profiles	profiles_id_fkey	foreign_key	FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
profiles	profiles_identifier_digits_check	check	CHECK (institutional_id_value IS NULL OR institutional_id_value ~ '^[0-9]+$'::text)
profiles	profiles_identifier_length_check	check	CHECK (institutional_id_value IS NULL OR char_length(institutional_id_value) >= 1 AND char_length(institutional_id_value) <= 50)
profiles	profiles_institutional_id_type_check	check	CHECK (institutional_id_type IS NULL OR (institutional_id_type = ANY (ARRAY['student_account'::text, 'worker_number'::text])))
profiles	profiles_maternal_surname_check	check	CHECK (maternal_surname IS NULL OR char_length(maternal_surname) >= 1 AND char_length(maternal_surname) <= 150 AND maternal_surname = regexp_replace(btrim(maternal_surname), '\s+'::text, ' '::text, 'g'::text))
profiles	profiles_paternal_surname_check	check	CHECK (paternal_surname IS NULL OR char_length(paternal_surname) >= 1 AND char_length(paternal_surname) <= 150 AND paternal_surname = regexp_replace(btrim(paternal_surname), '\s+'::text, ' '::text, 'g'::text))
profiles	profiles_person_type_check	check	CHECK (person_type IS NULL OR (person_type = ANY (ARRAY['student'::text, 'professor'::text])))
profiles	profiles_pkey	primary_key	PRIMARY KEY (id)
profiles	profiles_primary_program_id_fkey	foreign_key	FOREIGN KEY (primary_program_id) REFERENCES academic_programs(id)
profiles	profiles_structured_full_name_check	check	CHECK (first_names IS NULL OR full_name = concat_ws(' '::text, first_names, paternal_surname, maternal_surname))
role_assignments	role_assignments_assigned_by_fkey	foreign_key	FOREIGN KEY (assigned_by) REFERENCES auth.users(id)
role_assignments	role_assignments_division_id_fkey	foreign_key	FOREIGN KEY (division_id) REFERENCES divisions(id) ON DELETE CASCADE
role_assignments	role_assignments_pkey	primary_key	PRIMARY KEY (id)
role_assignments	role_assignments_program_id_fkey	foreign_key	FOREIGN KEY (program_id) REFERENCES academic_programs(id) ON DELETE CASCADE
role_assignments	role_assignments_role_code_fkey	foreign_key	FOREIGN KEY (role_code) REFERENCES roles(code)
role_assignments	role_assignments_scope_type_check	check	CHECK (scope_type = ANY (ARRAY['own'::text, 'program'::text, 'division'::text, 'system'::text]))
role_assignments	role_assignments_service_area_check	check	CHECK (service_area = ANY (ARRAY['tutoring'::text, 'advising'::text, 'both'::text, 'logistics'::text, 'technical'::text]))
role_assignments	role_assignments_user_id_fkey	foreign_key	FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
role_assignments	valid_role_assignment_scope	check	CHECK (scope_type = 'own'::text AND division_id IS NULL AND program_id IS NULL OR scope_type = 'program'::text AND program_id IS NOT NULL OR scope_type = 'division'::text AND division_id IS NOT NULL OR scope_type = 'system'::text AND division_id IS NULL AND program_id IS NULL)
roles	roles_pkey	primary_key	PRIMARY KEY (code)
service_types	service_types_pkey	primary_key	PRIMARY KEY (code)
system_health	system_health_pkey	primary_key	PRIMARY KEY (id)
