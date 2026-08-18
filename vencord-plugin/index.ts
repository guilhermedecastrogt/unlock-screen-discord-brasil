import definePlugin from "@utils/types";
import { Devs } from "@utils/constants";
import { FluxDispatcher } from "@webpack/common";

const EXPERIMENT = "2026-08-video-guard";

function disableGuard() {
    FluxDispatcher.dispatch({
        type: "APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE",
        experimentName: EXPERIMENT,
        variantId: 0
    });
    console.log(`[VideoGuardOff] override applied to ${EXPERIMENT}`);
}

export default definePlugin({
    name: "VideoGuardOff",
    description: "Reapplies the screen/video guard experiment override on every session. Educational PoC.",
    authors: [Devs.Ven],

    flux: {
        CONNECTION_OPEN: disableGuard
    },

    start: disableGuard
});
