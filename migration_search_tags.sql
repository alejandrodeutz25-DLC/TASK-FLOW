sql
-- Migración: agregar búsqueda avanzada de tareas
ALTER TABLE tasks ADD COLUMN search_tags VARCHAR(255);
CREATE INDEX idx_tasks_search ON tasks (search_tags, created_at);
