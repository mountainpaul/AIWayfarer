# Repositories own all SQL execution (BEST_PRACTICES.md §2.1). Import the
# concrete repository modules directly (e.g. `from ..repositories.base import
# BaseRepository`) rather than re-exporting here, so parallel feature branches
# never contend on this file.
