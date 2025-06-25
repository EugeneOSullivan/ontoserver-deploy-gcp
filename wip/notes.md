# Ontoserver Deployment Debug Summary

Documentation:  
https://ontoserver.csiro.au/docs/

---

## Issues Observed

- Ontoserver pod starts successfully with no critical errors.
- Logs show successful preload of some StructureDefinitions and artefacts.
- Frequent WARN logs:  
  - "No mapping for GET /fhir/metadata"  
  - "No mapping for GET /api/codeSystems"  
  - "No mapping for GET /api/version"  
- curl requests to:
  - http://localhost:18080/api/version → 404 Not Found, "No endpoint GET /api/version."
  - http://localhost:18080/api/codeSystems → 404 Not Found, "No endpoint GET /api/codeSystems."
  - http://localhost:18080/fhir/metadata → 404 Not Found, "No mapping for GET /fhir/metadata"
- Port-forward errors (kubernetes):
  - Connection refused on localhost:18080 inside pod network namespace.
  - Indicates possible networking or port forwarding issues.
- No swagger or landing page response tested yet.
- Database (Postgres) connections and migrations appear OK.
- SSL certificate generated successfully.
- Ontoserver profiles active: "ontoserver", "syndication", "ssl".

---

## What Has Been Tried

- Confirmed pod logs show Ontoserver startup and preload completed.
- curl to API endpoints on port 18080 returns 404 for known Ontoserver REST endpoints.
- Verified active profiles and that no startup crashes occur.
- Checked logs for Spring warnings about unmapped paths.
- Noted missing REST API mappings for both `/api/*` and `/fhir/*`.
- Checked for any possible misconfiguration of REST API base path.
- Port-forwarding commands used; connection refused errors seen intermittently.
- Reviewed logs for Flyway DB migrations (successful).
- Confirmed Ontoserver version and Java version from logs.

---

## Hypotheses & Next Steps

1. **REST API module missing or disabled:**  
   - Possible that the REST API controllers are not loaded or disabled by config.

2. **Incorrect base path or context path configuration:**  
   - Check `server.servlet.context-path` or Ontoserver-specific API path config.

3. **Networking / port-forwarding issues:**  
   - Ensure port-forwarding is correctly set up and no network policies block access.

4. **Verify if Ontoserver UI or Swagger endpoints are accessible:**  
   - Test `/swagger-ui.html`, `/api/docs`, or root `/`.

5. **Check Kubernetes ingress or service path rewriting**  
   - Confirm no path rewrite or prefixing affects requests.

6. **Test with default Ontoserver configuration and image**  
   - Isolate if issue is config or custom deployment.

---

## Recommendations

- Review Ontoserver config files (application.properties, environment variables).
- Confirm API paths and enabled modules.
- Try direct pod port-forward and curl calls without proxy/ingress.
- Look for Swagger or landing page endpoints to verify API availability.
- Consult Ontoserver logs again for any startup warnings/errors.
- Compare deployment manifests with official Ontoserver GCP deployment docs.

---

# End of Summary
