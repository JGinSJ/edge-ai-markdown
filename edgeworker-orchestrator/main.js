import { httpRequest } from 'http-request';

export async function onClientRequest(request) {
    try {
        // getHeader() returns string[] in the EdgeWorkers API, not a plain string.
        const isVerifiedBot = (request.getHeader('x-verified-bot') ?? []).includes('true');
        const acceptHeader = request.getHeader('accept') ?? [];
        const acceptsMarkdown = acceptHeader.some(v => v.includes('text/markdown'));

        if (isVerifiedBot || acceptsMarkdown) {
            
            // Target URL: prefer ?url= query param (demo UI mode), fall back to the
            // actual request URL (production property mode — no redeployment needed).
            let targetUrl = null;
            if (request.query) {
                const queryMatch = request.query.match(/url=([^&]+)/);
                if (queryMatch) targetUrl = decodeURIComponent(queryMatch[1]);
            }
            if (!targetUrl) {
                const host = (request.getHeader('host') ?? [])[0] ?? request.host;
                targetUrl = 'https://' + host + request.path;
            }

            if (!/^https?:\/\//i.test(targetUrl)) targetUrl = 'https://' + targetUrl;

            const wasmFunctionUrl = "https://bede2402-c4b7-4234-b17c-5e04fc46ef00.fwf.app";

            const wasmResponse = await httpRequest(wasmFunctionUrl, {
                method: 'GET',
                headers: { 'X-Target-URL': [targetUrl] }
            });

            if (wasmResponse.ok) {
                // Cap at 100,000 bytes to avoid exhausting EdgeWorker heap on large HTML pages.
                const markdownBody = await wasmResponse.text(100000);
                // respondWith() buffers the full body in memory before sending. The EdgeWorker
                // runtime enforces a hard limit; 1,900 chars keeps the payload safely under it.
                const truncatedMarkdown = markdownBody.substring(0, 1900) + "\n\n...[MARKDOWN TRUNCATED FOR EDGEWORKER DEMO]...";

                request.respondWith(200, {
                    'Content-Type': ['text/markdown; charset=utf-8'],
                    'X-Wasm-Execution': ['success'], 
                    'Cache-Control': ['max-age=3600, public']
                }, truncatedMarkdown);
            } else {
                const err = await wasmResponse.text();
                request.respondWith(500, {'X-Wasm-Execution': ['failed']}, `Wasm Error: ${err}`);
            }
        }
    } catch (error) {
        request.respondWith(500, {'X-Wasm-Execution': ['crashed']}, `EdgeWorker Error: ${error.message}`);
    }
}