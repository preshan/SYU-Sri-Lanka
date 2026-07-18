/// Maps admin deep-link / query names to AdminShell tab indexes.
int? adminTabIndexFromName(String? tab) {
  if (tab == null || tab.isEmpty) return null;
  return switch (tab) {
    'members' => 1,
    'clubs' => 2,
    'news' => 3,
    'events' => 4,
    'chat' => 5,
    'broadcast' => 6,
    'reports' => 7,
    'audit' => 8,
    'mail' => 9,
    'approvals' => 0,
    _ => int.tryParse(tab),
  };
}
