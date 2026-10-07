-- Preserve the shared Recall/SAVY theme and full question-and-answer fields through sync.
-- Nullable columns keep existing reminders and older clients compatible.
alter table recall.reminders
    add column if not exists post_theme_id text,
    add column if not exists post_theme_name text,
    add column if not exists post_answers text[],
    add column if not exists post_answers_contain_questions boolean;

notify pgrst, 'reload schema';
