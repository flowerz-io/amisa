#!/usr/bin/env node
/**
 * Client secret JWT Apple pour Supabase Auth (Sign in with Apple).
 *
 * Usage :
 *   cd scripts/apple-supabase-secret
 *   npm install
 *   npm run generate
 *
 * Variables d'environnement (optionnelles) :
 *   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID, APPLE_PRIVATE_KEY_PATH
 */

const fs = require("fs");
const path = require("path");
const jwt = require("jsonwebtoken");

const APPLE_TEAM_ID = process.env.APPLE_TEAM_ID ?? "V27382NYDY";
const APPLE_KEY_ID = process.env.APPLE_KEY_ID ?? "TMR6X2J88M";
const APPLE_CLIENT_ID = process.env.APPLE_CLIENT_ID ?? "io.flowerz.Amisa.app";
const APPLE_PRIVATE_KEY_PATH =
  process.env.APPLE_PRIVATE_KEY_PATH ??
  path.join(process.env.HOME ?? "", "Downloads", "AuthKey_TMR6X2J88M.p8");

/** Durée max autorisée par Apple pour le client secret (~6 mois). */
const MAX_EXPIRATION_SECONDS = 15777000;

function main() {
  if (!fs.existsSync(APPLE_PRIVATE_KEY_PATH)) {
    console.error(
      `Fichier clé introuvable : ${APPLE_PRIVATE_KEY_PATH}\n` +
        "Définissez APPLE_PRIVATE_KEY_PATH vers votre AuthKey_*.p8"
    );
    process.exit(1);
  }

  const privateKey = fs.readFileSync(APPLE_PRIVATE_KEY_PATH, "utf8");
  const now = Math.floor(Date.now() / 1000);

  const token = jwt.sign(
    {
      iss: APPLE_TEAM_ID,
      iat: now,
      exp: now + MAX_EXPIRATION_SECONDS,
      aud: "https://appleid.apple.com",
      sub: APPLE_CLIENT_ID,
    },
    privateKey,
    {
      algorithm: "ES256",
      header: {
        alg: "ES256",
        kid: APPLE_KEY_ID,
      },
    }
  );

  const expiresAt = new Date((now + MAX_EXPIRATION_SECONDS) * 1000);

  console.log("\n=== Apple client secret (JWT) pour Supabase ===\n");
  console.log("Team ID (issuer):", APPLE_TEAM_ID);
  console.log("Key ID (kid):    ", APPLE_KEY_ID);
  console.log("Client ID (sub): ", APPLE_CLIENT_ID);
  console.log("Expire le:       ", expiresAt.toISOString());
  console.log("\n--- Collez ci-dessous dans Supabase > Auth > Providers > Apple > Secret Key ---\n");
  console.log(token);
  console.log("\n--- Fin du secret ---\n");
}

main();
