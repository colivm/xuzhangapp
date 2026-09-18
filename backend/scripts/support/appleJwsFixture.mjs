import { readFileSync } from "node:fs";
import { X509Certificate } from "node:crypto";
import jwt from "jsonwebtoken";

const fixtureRoot = new URL("../fixtures/apple-jws-test/", import.meta.url);
const read = (name) => readFileSync(new URL(name, fixtureRoot));
const leafKey = read("leaf-key.pem");
const chain = ["leaf.pem", "intermediate.pem", "root.pem"]
  .map((name) => new X509Certificate(read(name)).raw.toString("base64"));

export const appleJwsFixtureRootPath = new URL("root.pem", fixtureRoot);

export function signedAppleTransaction(payload, header = {}) {
  return jwt.sign(payload, leafKey, {
    algorithm: "ES256",
    noTimestamp: true,
    header: { alg: "ES256", x5c: chain, ...header },
  });
}
