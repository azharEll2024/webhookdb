import "../styles/custom.scss";

import Centered from "../components/Centered";
import { Container } from "react-bootstrap";
import LayoutPage from "../components/LayoutPage";
import React from "react";
import Waves from "../components/Waves";

export default function WavesHeaderLayout({ header, children }) {
  return (
    <LayoutPage center>
      <Container className="bg-primary text-light pt-5 px-4" fluid>
        <Centered>{header}</Centered>
      </Container>
      <Waves height={100} />
      <Container className="px-4 mb-5" fluid>
        <Centered>{children}</Centered>
        <div className="py-2" />
      </Container>
    </LayoutPage>
  );
}