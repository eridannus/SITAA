-- table	position	column	data_type	udt_name	nullable	default	char_max_length	numeric_precision	numeric_scale	datetime_precision
academic_periods	1	id	uuid	uuid	NO	gen_random_uuid()				
academic_periods	2	code	text	text	NO					
academic_periods	3	name	text	text	NO					
academic_periods	4	starts_on	date	date	YES					0
academic_periods	5	ends_on	date	date	YES					0
academic_periods	6	is_active	boolean	bool	NO	true				
academic_periods	7	sort_order	integer	int4	NO	0		32	0	
academic_periods	8	created_at	timestamp with time zone	timestamptz	NO	now()				6
academic_periods	9	updated_at	timestamp with time zone	timestamptz	NO	now()				6
academic_programs	1	id	uuid	uuid	NO	gen_random_uuid()				
academic_programs	2	division_id	uuid	uuid	NO					
academic_programs	3	code	text	text	NO					
academic_programs	4	name	text	text	NO					
academic_programs	5	created_at	timestamp with time zone	timestamptz	NO	now()				6
academic_programs	6	is_active	boolean	bool	NO	true				
activities	1	id	uuid	uuid	NO	gen_random_uuid()				
activities	2	title	text	text	NO					
activities	3	description	text	text	YES					
activities	4	academic_period_id	uuid	uuid	YES					
activities	5	program_id	uuid	uuid	YES					
activities	6	activity_type_code	text	text	YES					
activities	7	service_type_code	text	text	YES					
activities	8	attention_category_code	text	text	YES					
activities	9	modality_code	text	text	YES					
activities	10	status_code	text	text	NO	'draft'::text				
activities	11	location_type_code	text	text	YES					
activities	12	location_detail	text	text	YES					
activities	13	starts_at	timestamp with time zone	timestamptz	YES					6
activities	14	ends_at	timestamp with time zone	timestamptz	YES					6
activities	15	responsible_profile_id	uuid	uuid	NO					
activities	16	created_by	uuid	uuid	NO	auth.uid()				
activities	17	updated_by	uuid	uuid	YES					
activities	18	created_at	timestamp with time zone	timestamptz	NO	now()				6
activities	19	updated_at	timestamp with time zone	timestamptz	NO	now()				6
activities	20	start_date	date	date	YES					0
activities	21	start_time	time without time zone	time	YES					6
activities	22	end_date	date	date	YES					0
activities	23	end_time	time without time zone	time	YES					6
activities	24	duration_mode	text	text	YES					
activities	25	scope_type	text	text	YES	'program'::text				
activities	26	division_id	uuid	uuid	YES					
activity_checkin_tokens	1	id	uuid	uuid	NO	gen_random_uuid()				
activity_checkin_tokens	2	activity_id	uuid	uuid	NO					
activity_checkin_tokens	3	token_type	text	text	NO	'attendance'::text				
activity_checkin_tokens	4	code_words	text	text	NO					
activity_checkin_tokens	5	secret_token	text	text	NO	(gen_random_uuid())::text				
activity_checkin_tokens	6	is_active	boolean	bool	NO	true				
activity_checkin_tokens	7	opened_at	timestamp with time zone	timestamptz	NO	now()				6
activity_checkin_tokens	8	closed_at	timestamp with time zone	timestamptz	YES					6
activity_checkin_tokens	9	expires_at	timestamp with time zone	timestamptz	YES					6
activity_checkin_tokens	10	created_by	uuid	uuid	NO	auth.uid()				
activity_checkin_tokens	11	created_at	timestamp with time zone	timestamptz	NO	now()				6
activity_modalities	1	code	text	text	NO					
activity_modalities	2	label	text	text	NO					
activity_modalities	3	description	text	text	YES					
activity_modalities	4	sort_order	integer	int4	NO	0		32	0	
activity_modalities	5	is_active	boolean	bool	NO	true				
activity_modalities	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
activity_modalities	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
activity_participants	1	id	uuid	uuid	NO	gen_random_uuid()				
activity_participants	2	activity_id	uuid	uuid	NO					
activity_participants	3	profile_id	uuid	uuid	NO					
activity_participants	4	participant_role_code	text	text	NO					
activity_participants	5	added_by	uuid	uuid	NO	auth.uid()				
activity_participants	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
activity_participants	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
activity_participants	8	attendance_status	text	text	NO	'pending'::text				
activity_participants	9	attendance_source	text	text	NO	'system'::text				
activity_participants	10	checked_in_at	timestamp with time zone	timestamptz	YES					6
activity_participants	11	attendance_updated_by	uuid	uuid	YES					
activity_participants	12	attendance_updated_at	timestamp with time zone	timestamptz	YES					6
activity_participants	13	attendance_notes	text	text	YES					
activity_statuses	1	code	text	text	NO					
activity_statuses	2	label	text	text	NO					
activity_statuses	3	description	text	text	YES					
activity_statuses	4	sort_order	integer	int4	NO	0		32	0	
activity_statuses	5	is_active	boolean	bool	NO	true				
activity_statuses	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
activity_statuses	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
activity_types	1	code	text	text	NO					
activity_types	2	label	text	text	NO					
activity_types	3	description	text	text	YES					
activity_types	4	sort_order	integer	int4	NO	0		32	0	
activity_types	5	is_active	boolean	bool	NO	true				
activity_types	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
activity_types	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
attention_categories	1	code	text	text	NO					
attention_categories	2	label	text	text	NO					
attention_categories	3	description	text	text	YES					
attention_categories	4	sort_order	integer	int4	NO	0		32	0	
attention_categories	5	is_active	boolean	bool	NO	true				
attention_categories	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
attention_categories	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
divisions	1	id	uuid	uuid	NO	gen_random_uuid()				
divisions	2	code	text	text	NO					
divisions	3	name	text	text	NO					
divisions	4	created_at	timestamp with time zone	timestamptz	NO	now()				6
location_types	1	code	text	text	NO					
location_types	2	label	text	text	NO					
location_types	3	description	text	text	YES					
location_types	4	sort_order	integer	int4	NO	0		32	0	
location_types	5	is_active	boolean	bool	NO	true				
location_types	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
location_types	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
participant_roles	1	code	text	text	NO					
participant_roles	2	label	text	text	NO					
participant_roles	3	description	text	text	YES					
participant_roles	4	sort_order	integer	int4	NO	0		32	0	
participant_roles	5	is_active	boolean	bool	NO	true				
participant_roles	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
participant_roles	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
profiles	1	id	uuid	uuid	NO					
profiles	2	email	text	text	NO					
profiles	3	full_name	text	text	YES					
profiles	4	primary_program_id	uuid	uuid	YES					
profiles	5	is_active	boolean	bool	NO	false				
profiles	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
profiles	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
profiles	8	first_names	text	text	YES					
profiles	9	paternal_surname	text	text	YES					
profiles	10	maternal_surname	text	text	YES					
profiles	11	person_type	text	text	YES					
profiles	12	institutional_id_type	text	text	YES					
profiles	13	institutional_id_value	text	text	YES					
profiles	14	account_kind	text	text	NO	'institutional'::text				
profiles	15	account_status	text	text	NO	'pending_registration'::text				
profiles	16	activated_at	timestamp with time zone	timestamptz	YES					6
profiles	17	deactivated_at	timestamp with time zone	timestamptz	YES					6
role_assignments	1	id	uuid	uuid	NO	gen_random_uuid()				
role_assignments	2	user_id	uuid	uuid	NO					
role_assignments	3	role_code	text	text	NO					
role_assignments	4	scope_type	text	text	NO					
role_assignments	5	service_area	text	text	NO					
role_assignments	6	division_id	uuid	uuid	YES					
role_assignments	7	program_id	uuid	uuid	YES					
role_assignments	8	starts_at	date	date	NO	CURRENT_DATE				0
role_assignments	9	ends_at	date	date	YES					0
role_assignments	10	is_active	boolean	bool	NO	true				
role_assignments	11	assigned_by	uuid	uuid	YES					
role_assignments	12	created_at	timestamp with time zone	timestamptz	NO	now()				6
role_assignments	13	updated_at	timestamp with time zone	timestamptz	NO	now()				6
roles	1	code	text	text	NO					
roles	2	label	text	text	NO					
roles	3	description	text	text	YES					
roles	4	sort_order	integer	int4	NO	0		32	0	
service_types	1	code	text	text	NO					
service_types	2	label	text	text	NO					
service_types	3	description	text	text	YES					
service_types	4	sort_order	integer	int4	NO	0		32	0	
service_types	5	is_active	boolean	bool	NO	true				
service_types	6	created_at	timestamp with time zone	timestamptz	NO	now()				6
service_types	7	updated_at	timestamp with time zone	timestamptz	NO	now()				6
system_health	1	id	bigint	int8	NO			64	0	
system_health	2	status	text	text	NO	'ok'::text				
system_health	3	message	text	text	NO	'Supabase conectado'::text				
system_health	4	created_at	timestamp with time zone	timestamptz	NO	now()				6
