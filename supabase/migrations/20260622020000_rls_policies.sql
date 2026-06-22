-- June Phase 3 — strict per-user RLS policies.
-- service_role bypasses RLS automatically.
-- anon role gets no access. authenticated users see only their own rows.

-- =====================================================================
-- users (special: keyed on id, not user_id)
-- =====================================================================
create policy "users_select_own" on users
  for select using (id = auth.uid());
create policy "users_update_own" on users
  for update using (id = auth.uid()) with check (id = auth.uid());

-- =====================================================================
-- goals
-- =====================================================================
create policy "goals_select_own" on goals
  for select using (user_id = auth.uid());
create policy "goals_insert_own" on goals
  for insert with check (user_id = auth.uid());
create policy "goals_update_own" on goals
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "goals_delete_own" on goals
  for delete using (user_id = auth.uid());

-- =====================================================================
-- accounts
-- =====================================================================
create policy "accounts_select_own" on accounts
  for select using (user_id = auth.uid());
create policy "accounts_insert_own" on accounts
  for insert with check (user_id = auth.uid());
create policy "accounts_update_own" on accounts
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "accounts_delete_own" on accounts
  for delete using (user_id = auth.uid());

-- =====================================================================
-- cards (linked via account_id → accounts.user_id)
-- =====================================================================
create policy "cards_select_own" on cards
  for select using (
    account_id in (select id from accounts where user_id = auth.uid())
  );
create policy "cards_insert_own" on cards
  for insert with check (
    account_id in (select id from accounts where user_id = auth.uid())
  );
create policy "cards_update_own" on cards
  for update using (
    account_id in (select id from accounts where user_id = auth.uid())
  ) with check (
    account_id in (select id from accounts where user_id = auth.uid())
  );
create policy "cards_delete_own" on cards
  for delete using (
    account_id in (select id from accounts where user_id = auth.uid())
  );

-- =====================================================================
-- transactions
-- =====================================================================
create policy "transactions_select_own" on transactions
  for select using (user_id = auth.uid());
create policy "transactions_insert_own" on transactions
  for insert with check (user_id = auth.uid());
create policy "transactions_update_own" on transactions
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "transactions_delete_own" on transactions
  for delete using (user_id = auth.uid());

-- =====================================================================
-- budget_targets
-- =====================================================================
create policy "budget_targets_select_own" on budget_targets
  for select using (user_id = auth.uid());
create policy "budget_targets_insert_own" on budget_targets
  for insert with check (user_id = auth.uid());
create policy "budget_targets_update_own" on budget_targets
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "budget_targets_delete_own" on budget_targets
  for delete using (user_id = auth.uid());

-- =====================================================================
-- checkins
-- =====================================================================
create policy "checkins_select_own" on checkins
  for select using (user_id = auth.uid());
create policy "checkins_insert_own" on checkins
  for insert with check (user_id = auth.uid());
create policy "checkins_update_own" on checkins
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "checkins_delete_own" on checkins
  for delete using (user_id = auth.uid());

-- =====================================================================
-- plaid_items
-- =====================================================================
create policy "plaid_items_select_own" on plaid_items
  for select using (user_id = auth.uid());
create policy "plaid_items_insert_own" on plaid_items
  for insert with check (user_id = auth.uid());
create policy "plaid_items_update_own" on plaid_items
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "plaid_items_delete_own" on plaid_items
  for delete using (user_id = auth.uid());

-- =====================================================================
-- category_overrides (composite key starts with user_id)
-- =====================================================================
create policy "category_overrides_select_own" on category_overrides
  for select using (user_id = auth.uid());
create policy "category_overrides_insert_own" on category_overrides
  for insert with check (user_id = auth.uid());
create policy "category_overrides_update_own" on category_overrides
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "category_overrides_delete_own" on category_overrides
  for delete using (user_id = auth.uid());
