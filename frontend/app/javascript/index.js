import { Application } from "stimulus";
import { definitionsFromContext } from "stimulus/webpack-helpers";

// Let stimulus require all controllers and generate identifiers for them.
const controllersContext = require.context(
  "./controllers",
  true,
  /_controller\.js$/
);
const controllersDefinitions = definitionsFromContext(controllersContext);

const application = Application.start();

application.load(controllersDefinitions);

export default {
  start() {
    console.log("Spree Frontend initialized");
  },
  controllers: controllersDefinitions,
};
