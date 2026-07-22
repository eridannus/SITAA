-- schema	table	policy	mode	roles	command	using	with_check
public	academic_periods	Authenticated users can read academic periods	PERMISSIVE	authenticated	SELECT	true	
public	academic_programs	Authenticated users can read academic programs	PERMISSIVE	authenticated	SELECT	true	
public	activities	Active accounts may operate activities	RESTRICTIVE	authenticated	ALL	is_sitaa_operational_account_active()	is_sitaa_operational_account_active()
public	activities	Authorized users can create activities	PERMISSIVE	authenticated	INSERT		((created_by = auth.uid()) AND can_create_activity(scope_type, program_id, division_id, service_type_code))
public	activities	Authorized users can delete activities	PERMISSIVE	authenticated	DELETE	can_delete_activity(id)	
public	activities	Authorized users can update activities	PERMISSIVE	authenticated	UPDATE	can_update_activity_base(id)	can_update_activity_base(id)
public	activities	Users can read permitted activities	PERMISSIVE	authenticated	SELECT	(((status_code = 'draft'::text) AND (created_by = auth.uid())) OR ((status_code <> 'draft'::text) AND ((created_by = auth.uid()) OR (responsible_profile_id = auth.uid()) OR is_activity_participant(id) OR can_manage_activity(scope_type, program_id, division_id, service_type_code))))	
public	activity_modalities	Authenticated users can read activity modalities	PERMISSIVE	authenticated	SELECT	true	
public	activity_participants	Active accounts may operate activity participants	RESTRICTIVE	authenticated	ALL	is_sitaa_operational_account_active()	is_sitaa_operational_account_active()
public	activity_participants	Users can add permitted activity participants	PERMISSIVE	authenticated	INSERT		can_edit_activity(activity_id)
public	activity_participants	Users can delete permitted activity participants	PERMISSIVE	authenticated	DELETE	can_edit_activity(activity_id)	
public	activity_participants	Users can read permitted activity participants	PERMISSIVE	authenticated	SELECT	((profile_id = auth.uid()) OR can_read_activity(activity_id))	
public	activity_participants	Users can update permitted activity participants	PERMISSIVE	authenticated	UPDATE	can_edit_activity(activity_id)	can_edit_activity(activity_id)
public	activity_statuses	Authenticated users can read activity statuses	PERMISSIVE	authenticated	SELECT	true	
public	activity_types	Authenticated users can read activity types	PERMISSIVE	authenticated	SELECT	true	
public	attention_categories	Authenticated users can read attention categories	PERMISSIVE	authenticated	SELECT	true	
public	divisions	Authenticated users can read divisions	PERMISSIVE	authenticated	SELECT	true	
public	location_types	Authenticated users can read location types	PERMISSIVE	authenticated	SELECT	true	
public	participant_roles	Authenticated users can read participant roles	PERMISSIVE	authenticated	SELECT	true	
public	profiles	Users can read own profile	PERMISSIVE	authenticated	SELECT	(auth.uid() = id)	
public	profiles	Users can update own basic profile	PERMISSIVE	authenticated	UPDATE	(auth.uid() = id)	(auth.uid() = id)
public	role_assignments	Users can read own role assignments	PERMISSIVE	authenticated	SELECT	(auth.uid() = user_id)	
public	roles	Authenticated users can read roles	PERMISSIVE	authenticated	SELECT	true	
public	service_types	Authenticated users can read service types	PERMISSIVE	authenticated	SELECT	true	
public	system_health	Allow public read for system health	PERMISSIVE	anon	SELECT	true	
