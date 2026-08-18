(() => {
    if (!Object.values(Vencord.Webpack.wreq(Vencord.Webpack.findModuleId("2026-08-video-guard"))).find(
        x => x?.definition?.name === "2026-08-video-guard"
    ))
        throw new Error("not found")

    Vencord.Webpack.Common.FluxDispatcher.dispatch({
        type: "APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE",
        experimentName: "2026-08-video-guard",
        variantId: 0
    });

    console.log("enabled!")
})();