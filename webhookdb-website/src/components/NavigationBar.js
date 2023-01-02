import "../styles/custom.scss";

import { Button, Image, Nav, NavDropdown, NavLink, Navbar } from "react-bootstrap";

import Lead from "./Lead";
import Logo from "../images/whiteonwhite.png";
import RLink from "./RLink";
import React from "react";
import clsx from "clsx";

export default function NavigationBar() {
  const itemCls = "align-self-end align-self-md-center text-right";
  return (
    <div className="bg-primary sitenav">
      <Navbar bg="primary" variant="dark" expand="md" className="pl-2 pr-4 bounded">
        <Nav.Link href="/" as={RLink}>
          <Image src={Logo} fluid />
        </Nav.Link>
        <Navbar.Toggle aria-controls="basic-navbar-nav" />
        <Navbar.Collapse id="basic-navbar-nav">
          <Nav className="justify-content-end w-100">
            <NavDropdown
              title="Solutions"
              id="solutions-dropdown"
              className={clsx(itemCls, "nav-dropdown nav-link-hover-invert")}
            >
              <NavDropdownItem
                href="/solutions/analytics"
                title="Analytics"
                text="Affordable, real-time, turnkey integration with for any 3rd party APIs."
              />
              <Sep />
              <NavDropdownItem
                href="/solutions/app-startups"
                title="Application Startups"
                text="Free developers and product managers to focus on your killer app's user experience, not backend API integration."
              />
              <Sep />
              <NavDropdownItem
                href="/solutions/development-agencies"
                title="Development Agencies"
                text="Deliver demanding projects faster than with current API integration paradigms."
              />
              <Sep />
              <NavDropdownItem
                href="/solutions/digital-transformation"
                title="Digital Transformation"
                text="Jumpstart your enterprise client's transformation journey with WebhookDB."
              />
              <Sep />
              <NavDropdownItem
                href="/solutions/enterprises"
                title="Enterprises"
                text="Solve the headaches of modernization and unification of external or internal services."
              />
              <Sep />
              <NavDropdownItem
                href="/solutions/fintech"
                title="Fintech"
                text="Rocket fuel for all your 3rd party integrations."
              />
              <Sep />
              <NavDropdownItem
                href="/solutions/no-code"
                title="No Code"
                text="Eliminate the dreaded complexity of 3rd party API integrations."
              />
            </NavDropdown>
            <NavDropdown
              title="Features"
              id="features-dropdown"
              className={clsx(itemCls, "nav-dropdown nav-link-hover-invert")}
            >
              <NavDropdownItem
                href="/docs/api2sql"
                title="API2SQL Architecture"
                text="Welcome to a new, superior paradigm for API integration."
              />
              <Sep />
              <NavDropdownItem
                href="/licensing"
                title="Licensing"
                text="Learn about our committed and progressive approach to licensing and partnering."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/api-reservoir"
                title="API Data Reservoir"
                text="Like a reservoir collects water and makes using it as simple as turning a tap, so WebhookDB does for API data."
              />
              <Sep />
              <NavDropdownItem
                href="/integrations"
                title="Integrations"
                text="See what public integrations we currently support."
              />
            </NavDropdown>
            <NavDropdown
              title="Developers"
              id="devs-dropdown"
              className={clsx(itemCls, "nav-dropdown nav-link-hover-invert")}
            >
              <NavDropdownItem
                href="/terminal"
                title="Terminal"
                text="Try WebhookDB's CLI directly from your browser."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/home"
                title="Documentation"
                text="Browse all WebhookDB guides and documentation."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/cli"
                title="Guide: Intro & Tutorial"
                text="Step-by-step walkthrough to get started syncing and using data with WebhookDB."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/self-hosting"
                title="Guide: Self Hosting"
                text="Learn how to self-host WebhookDB on your own database and/or infrastructure."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/integrating"
                title="Guide: Integrating WebhookDB"
                text="Learn how to integrate your WebhookDB database into your applications, analytics, and unit tests."
              />
            </NavDropdown>
            <Nav.Item className={itemCls}>
              <Nav.Link href="/pricing" as={RLink} className="nav-link-hover-invert">
                Pricing
              </Nav.Link>
            </Nav.Item>
            <Nav.Item className={itemCls}>
              <NavLink href="/download" as={RLink} className="nav-link-nohover">
                <Button className="rounded-pill" variant="outline-light">
                  Download
                </Button>
              </NavLink>
            </Nav.Item>
          </Nav>
        </Navbar.Collapse>
      </Navbar>
    </div>
  );
}

function NavDropdownItem({ title, text, href }) {
  return (
    <NavDropdown.Item href={href} as={RLink}>
      <Lead className="mb-1">{title}</Lead>
      <p style={{ whiteSpace: "normal" }} className="mb-0">
        {text}
      </p>
    </NavDropdown.Item>
  );
}

function Sep() {
  return <hr className="mx-3" />;
}
