chrome.runtime.onInstalled.addListener(details => {
	switch (details.reason) {
		case "install": {
			chrome.storage.local.set({
				"serverUrl": serverURL
				, "collectionHistory": []
				,
			});

			break;
		}
	}

	return true;
});