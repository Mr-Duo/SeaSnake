from pathlib import Path
from harbor.agents.installed.mini_swe_agent import MiniSweAgent

SNAP_LOCAL = str(Path(__file__).parent / "snap.sh")
SNAP_REMOTE = "/snap.sh"
SNAP_WORKDIR = "/app"  # Match the Harbor task's configured workdir.


class MiniSweAgent(MiniSweAgent):
    async def run(self, instruction, environment, context):
        await environment.upload_file(SNAP_LOCAL, SNAP_REMOTE)

        await self.exec_as_root(
            environment,
            command=(
                f"chmod +x {SNAP_REMOTE} && "
                f"export SNAP_WORKDIR={SNAP_WORKDIR!r} && "
                f"{SNAP_REMOTE} before"
            ),
        )

        try:
            # await super().run(instruction, environment, context)
            pass
        finally:
            await self.exec_as_root(
                environment,
                command=(
                    f"export SNAP_WORKDIR={SNAP_WORKDIR!r} && "
                    f"{SNAP_REMOTE} after && "
                    f"rm -f {SNAP_REMOTE}"
                ),
            )