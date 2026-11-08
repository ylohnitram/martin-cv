#!/usr/bin/env bash
# Print data.json for the block explorer on the site: latest commit, commit count
# and merged PR count per project, read from GitHub in one GraphQL query.
#
# Needs GH_TOKEN. In Actions that is the STATS_TOKEN secret (read-only token that
# can see the private Replikanti repos), falling back to github.token, which only
# sees public repos. Private repos never publish a commit hash, only counts and
# dates. A repo the token cannot see comes out null and "partial" is set, so the
# page keeps its built-in snapshot for those fields.
set -euo pipefail

read -r -d '' QUERY <<'GQL' || true
query {
  core: repository(owner: "Replikanti", name: "agentis-core") { ...R }
  agentis: repository(owner: "Replikanti", name: "agentis") { ...R }
  colonies: repository(owner: "Replikanti", name: "agentis-colonies") {
    ...R
    df: defaultBranchRef { target { ... on Commit {
      history(path: "dark-factory", first: 1) { totalCount nodes { oid committedDate } }
    } } }
  }
  mie: repository(owner: "Replikanti", name: "mie") { ...R }
  flat: repository(owner: "Replikanti", name: "flat-cyborg") { ...R }
  bench: repository(owner: "Replikanti", name: "sdlc-bench") { ...R }
  kenny: repository(owner: "Replikanti", name: "kenny") { ...R }
  scam: repository(owner: "Replikanti", name: "interviewscam") { ...R }
  mandate: repository(owner: "ylohnitram", name: "agent-mandate-evals") { ...R }
}
fragment R on Repository {
  isPrivate
  pullRequests(states: MERGED) { totalCount }
  defaultBranchRef { target { ... on Commit { oid committedDate history { totalCount } } } }
}
GQL

# gh exits non-zero when some alias is not visible, but still prints the rest.
raw="$(gh api graphql -f query="$QUERY" 2>/dev/null || true)"

jq -e '.data' >/dev/null 2>&1 <<<"$raw" || { echo "fetch-stats: no data from GitHub" >&2; exit 1; }

jq '
  def repo:
    if . == null then null else
      (.defaultBranchRef.target) as $t
      | { private: .isPrivate,
          commits: $t.history.totalCount,
          date: $t.committedDate,
          prs: .pullRequests.totalCount,
          oid: (if .isPrivate then null else $t.oid end) }
    end;
  .data as $d
  | { core: ($d.core | repo), agentis: ($d.agentis | repo), colonies: ($d.colonies | repo),
      mie: ($d.mie | repo), flat: ($d.flat | repo), bench: ($d.bench | repo),
      kenny: ($d.kenny | repo), scam: ($d.scam | repo), mandate: ($d.mandate | repo),
      df: ($d.colonies.df.target.history // null
           | if . == null then null
             else { private: false, commits: .totalCount,
                    date: .nodes[0].committedDate, oid: .nodes[0].oid } end) } as $r
  | { generated: (now | todate),
      partial: ([$r[] | select(. == null)] | length > 0),
      total_prs: ([$r | to_entries[] | select(.key != "df" and .key != "mandate") | .value.prs // 0] | add),
      repos: $r }
' <<<"$raw"
