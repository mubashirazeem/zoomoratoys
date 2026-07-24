import DrawerControllerBase from "controllers/drawer_controller_base"

// Mobile/tablet admin sidebar drawer — see DrawerControllerBase for the
// shared open/close/focus-trap behavior. Below lg, the sidebar is an
// off-canvas panel; at lg and up it's a static column (see admin/_sidebar).
export default class extends DrawerControllerBase {}
