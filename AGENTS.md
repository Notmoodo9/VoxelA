# Development instructions

- Implement engine code in NASM assembly; GLSL shaders and test/build tooling are the documented exceptions.
- Follow README.md's engine contracts and report unfinished capabilities accurately.
- Validate changed systems with meaningful tests, including both ABI variants where relevant. Native Windows execution must not be inferred from Linux ABI tests or cross-linking.
- The user explicitly requests committing and pushing code changes to GitHub at the end of every coding turn. Push only after applicable validation; never force-push. Preserve unrelated user changes. If a push fails, report the blocker and retain local commits.
- Use the existing isolated checkout; do not create a worktree unless explicitly requested.

- All future graphical work follows `docs/graphics-direction.md`: stylized fantasy, vibrant dreamlike atmosphere, original 64×64 pixel art, warm rustic UI, High default with cheaper presets. Preserve the requested effect priorities and distinguish implemented effects from planned ones.

- Distant terrain must derive from the actual world generator and saved terrain, with progressive detail. Do not render an independent experimental generator as the playable horizon. Follow `docs/landscape-and-distance.md`.
