import "../styles/custom.scss";

import API2SQL from "../components/API2SQL";
import CtaAction from "../components/CtaAction";
import Hilite from "../components/Hilite";
import Lead from "../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../components/Seo";
import WavesHeaderCta from "../components/WavesHeaderCta";
import WavesHeaderLayout from "../components/WavesHeaderLayout";

export default function DigitalTransformation() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for Digital Transformation</h1>
          <Lead>
            WebhookDB empowers digital transformation consultancies and digital-first
            agencies to seamlessly unify and embed API data flows within external and
            internal applications.
          </Lead>
          <WavesHeaderCta>Get Started with WebhookDB</WavesHeaderCta>
        </>
      }
    >
      <Seo title="App Startups" />
      <Lead className="mt-4">
        WebhookDB and its novel{" "}
        <Link to="/docs/api2sql">&ldquo;{API2SQL}&rdquo; approach</Link> will help you:
      </Lead>
      <ul className="lead mb-5">
        <li>
          Jumpstart your enterprise client’s transformation journey with WebhookDB
        </li>
        <li>
          Change the game in application integration by unifying API data flows within
          WebhookDB
        </li>
        <li>
          <Hilite>
            Align with the fast emerging <strong>MACH</strong>
          </Hilite>{" "}
          (microservices, API-first, composable, headless) partner ecosystem
        </li>
        <li>
          Capitalize on <Hilite>WebhookDB product integrations</Hilite> across the API
          economy
        </li>
        <li>
          Develop partner-specific integrations for <Hilite>internal services</Hilite>
        </li>
        <li>
          Deliver client value <Hilite>ahead of schedule at lower cost</Hilite>, while
          increasing developer productivity
        </li>
        <li>Avoid problematic iPaaS lock-in within your customer set</li>
        <li>
          Private-label and customize WebhookDB as a core capability within your
          transformation services portfolio
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
