sql
-- Hotfix: rollback columna search_tags sin default
-- Causaba table lock en endpoint de login
ALTER TABLE tasks DROP COLUMN search_tags;
DROP INDEX idx_tasks_search;
