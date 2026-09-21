class Page
{
	constructor(win) {
		[this.win, {"document": this.doc, "location": this.loc,},] = [win, win,];
	}

	getCatalogList() {
		return [
			"/skupka-kartridzhey/hp/"
			, "/skupka-kartridzhey/canon/"
			, "/skupka-kartridzhey/xerox/"
			, "/skupka-kartridzhey/samsung/"
			, "/skupka-kartridzhey/kyocera/"
			, "/skupka-kartridzhey/brother/"
			, "/skupka-kartridzhey/panasonic/"
			, "/skupka-kartridzhey/ricoh/"
			, "/skupka-kartridzhey/lexmark/"
			, "/skupka-kartridzhey/oki/"
			, "/skupka-kartridzhey/konica-minolta/"
			, "/skupka-kartridzhey/pantum/"
			, "/skupka-kartridzhey/epson/"
			, "/skupka-kartridzhey/sharp/"
			, "/skupka-kartridzhey/toshiba/"
			, "/skupka-kartridzhey/oce/"
			, "/skupka-kartridzhey/katyusha/"
			, "/skupka-kartridzhey/sindoh/"
			,
		];
	}

	getNextCatalog() {
		const paths = this.getCatalogList();

		const url = new URL(this.loc.href, this.loc.origin);
		const idx = paths.findIndex(item => url.pathname.startsWith(item));

		if (idx > paths.length - 2) return null;

		url.pathname = paths[idx == -1 ? 0 : idx + 1];

		return url;
	}

	getNextPage() {
		return this.doc
			.querySelector(".module-pagination .cur + a")
			?.getAttribute("href");
	}

	getData() {
		const brand = this.doc
			.getElementById("pagetitle")
			?.textContent
			.substr("Скупка картриджей ".length);

		const cssTitle = [".type_block", ".color_block", ".sa_block_models .muted",];

		return [... this.doc.querySelectorAll(".inner_wrap")]
			.map(item => ({
				"brand": brand
				, "name": item.querySelector(".item-title")?.textContent?.trim()
				, "title": [... item.querySelectorAll(cssTitle)]
					.map(node => node?.textContent?.trim())
					.filter(text => text && text.length)
					.join(' ')
				, "image": item.querySelector("*[itemprop='image']").getAttribute("src")
				, "href": item.querySelector(".item-title")?.getAttribute("href")
				, "price": item.querySelector(".js_price_wrapper .price[data-value]")?.dataset.value
				, "art": item.querySelector(".article_block")?.dataset.value
				,
			}));
	}
}

const page = new Page(window);

function onPageLoad() {
	const fn = () => {
		if (!page.doc.querySelector(".inner_wrap .js_price_wrapper .price[data-value]"))
			return setTimeout(fn, 200);

		const data = page.getData();
		const form = page.doc.createElement("form");
		const input = page.doc.createElement("textarea");
		const iframe = page.doc.createElement("iframe");
		const nid = "id".concat(Math.random());

		form.setAttribute("action", "https://rashod.ru/tonerservice.ru.php");
		form.setAttribute("method", "POST");
		form.setAttribute("target", nid);
		iframe.setAttribute("name", nid);
		input.setAttribute("name", "data");
		input.value = JSON.stringify(data);

		form.appendChild(input);
		page.doc.body.appendChild(form);
		page.doc.body.appendChild(iframe);
		form.submit();

		const url = page.getNextPage() || page.getNextCatalog();

		if (url)
		 	page.loc.href = url;
		else
		 	setTimeout(() => page.loc.href = page.getCatalogList()[0], 1000 * 60 * 60 * 3);
	};

	fn();
}

page.doc.readyState === "loading"
	? page.doc.addEventListener("DOMContentLoaded", onPageLoad)
		: onPageLoad();