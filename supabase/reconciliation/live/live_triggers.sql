-- table	trigger	definition
activities	set_activities_updated_at	CREATE TRIGGER set_activities_updated_at BEFORE UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION set_updated_at()
activity_participants	set_activity_participants_updated_at	CREATE TRIGGER set_activity_participants_updated_at BEFORE UPDATE ON activity_participants FOR EACH ROW EXECUTE FUNCTION set_updated_at()
profiles	set_profiles_updated_at	CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at()
role_assignments	set_role_assignments_updated_at	CREATE TRIGGER set_role_assignments_updated_at BEFORE UPDATE ON role_assignments FOR EACH ROW EXECUTE FUNCTION set_updated_at()
