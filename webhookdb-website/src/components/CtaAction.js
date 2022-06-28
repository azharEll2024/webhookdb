import ContactForm from "./ContactForm";
import Lead from "./Lead";
import { Link } from "gatsby";
import React from "react";
import clsx from "clsx";

export default function CtaAction({ alt, className, formClassName }) {
  const [contactState, setContactState] = React.useState(null);
  const linkCls = alt ? "text-light font-weight-bold" : "";
  return (
    <div className={className}>
      <Lead>
        If you&rsquo;re interested in taking WebhookDB for a spin using our publicly
        available integrations, head on over to the{" "}
        <Link to="/terminal" className={linkCls}>
          terminal
        </Link>{" "}
        and get started from your browser. You can upgrade to a pain plan, or{" "}
        <Link to="/docs/self-hosting" className={linkCls}>
          switch to self-hosting
        </Link>
        , later.
      </Lead>
      <Lead>
        To discuss licensing WebhookDB for self-hosting, embedded use as OEM, and
        additional or custom integrations, please use this contact form, or email{" "}
        <a href="mailto:hello@webhookdb.com" className={linkCls}>
          hello@webhookdb.com
        </a>
        .
      </Lead>
      <ContactForm
        state={contactState}
        setState={setContactState}
        hideEmail
        alt={alt}
        className={clsx("max-width-sm", formClassName)}
      />
    </div>
  );
}