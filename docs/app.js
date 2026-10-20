(() => {
  "use strict";

  const root = document.documentElement;
  const header = document.querySelector(".site-header");
  const menuButton = document.querySelector(".menu-toggle");
  const mainNav = document.querySelector(".main-nav");

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Header state and mobile navigation
  const updateHeader = () => {
    if (!header) return;
    header.classList.toggle("scrolled", window.scrollY > 12);
  };

  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  if (menuButton && mainNav) {
    const closeMenu = () => {
      header.classList.remove("nav-open");
      menuButton.setAttribute("aria-expanded", "false");
      menuButton.setAttribute("aria-label", "Open navigation menu");
    };

    menuButton.addEventListener("click", () => {
      const isOpen = header.classList.toggle("nav-open");
      menuButton.setAttribute("aria-expanded", String(isOpen));
      menuButton.setAttribute("aria-label", isOpen ? "Close navigation menu" : "Open navigation menu");
    });

    mainNav.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu));
    document.addEventListener("click", (event) => {
      if (!header.classList.contains("nav-open")) return;
      if (!mainNav.contains(event.target) && !menuButton.contains(event.target)) closeMenu();
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") closeMenu();
    });
  }

  // Reveal sections as they enter the viewport
  const revealItems = Array.from(document.querySelectorAll(".reveal"));
  if (!("IntersectionObserver" in window) || reducedMotion) {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  } else {
    const revealObserver = new IntersectionObserver(
      (entries, observer) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    revealItems.forEach((item) => revealObserver.observe(item));
  }

  // Keep the active nav item in sync with the visible section
  const navLinks = Array.from(document.querySelectorAll(".main-nav a[href^='#']"));
  const sections = navLinks
    .map((link) => document.querySelector(link.getAttribute("href")))
    .filter(Boolean);

  if ("IntersectionObserver" in window && sections.length) {
    const sectionObserver = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((entry) => entry.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
        if (!visible) return;
        navLinks.forEach((link) => {
          link.classList.toggle("active", link.getAttribute("href") === `#${visible.target.id}`);
        });
      },
      { rootMargin: "-25% 0px -60% 0px", threshold: [0.01, 0.25] }
    );
    sections.forEach((section) => sectionObserver.observe(section));
  }

  // Lightweight Swift syntax highlighting for static snippets
  const keywords = new Set([
    "actor", "any", "as", "async", "await", "case", "catch", "class", "continue",
    "default", "defer", "do", "else", "enum", "extension", "false", "final", "for",
    "func", "guard", "if", "import", "in", "indirect", "init", "internal", "is",
    "let", "nil", "open", "private", "protocol", "public", "repeat", "return",
    "self", "Self", "static", "struct", "super", "switch", "throw", "throws",
    "true", "try", "typealias", "var", "where", "while"
  ]);

  const builtinTypes = new Set([
    "String", "Int", "Int64", "Double", "Float", "Bool", "Date", "Data", "URL",
    "URLSession", "URLQueryItem", "URLRequest", "URLComponents", "JSONDecoder",
    "JSONEncoder", "Codable", "Decodable", "Encodable", "Sendable", "CaseIterable",
    "LocalizedError", "Error", "DecodingError", "Void", "Optional", "Array",
    "Dictionary", "HTTPURLResponse", "URLResponse"
  ]);

  const escapeHTML = (value) =>
    value
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");

  const highlightSwift = (source) => {
    let result = "";
    let index = 0;
    let lastWord = "";

    const wordPattern = /^[A-Za-z_][A-Za-z0-9_]*/;
    const numberPattern = /^(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)/;

    while (index < source.length) {
      const rest = source.slice(index);
      const character = source[index];

      if (rest.startsWith("//")) {
        const newline = source.indexOf("\n", index);
        const end = newline === -1 ? source.length : newline;
        result += `<span class="tok-com">${escapeHTML(source.slice(index, end))}</span>`;
        index = end;
        continue;
      }

      if (character === "\"") {
        let end = index + 1;
        let escaped = false;
        while (end < source.length) {
          const next = source[end];
          if (next === "\"" && !escaped) {
            end += 1;
            break;
          }
          if (next === "\\" && !escaped) {
            escaped = true;
          } else {
            escaped = false;
          }
          end += 1;
        }
        result += `<span class="tok-str">${escapeHTML(source.slice(index, end))}</span>`;
        index = end;
        lastWord = "";
        continue;
      }

      if (character === "@") {
        const match = rest.match(/^@[A-Za-z_][A-Za-z0-9_]*/);
        if (match) {
          result += `<span class="tok-attr">${escapeHTML(match[0])}</span>`;
          index += match[0].length;
          continue;
        }
      }

      if (character === "`") {
        const closing = source.indexOf("`", index + 1);
        const end = closing === -1 ? source.length : closing + 1;
        result += `<span class="tok-esc">${escapeHTML(source.slice(index, end))}</span>`;
        index = end;
        continue;
      }

      const numberMatch = rest.match(numberPattern);
      if (numberMatch) {
        result += `<span class="tok-num">${escapeHTML(numberMatch[0])}</span>`;
        index += numberMatch[0].length;
        lastWord = "";
        continue;
      }

      const wordMatch = rest.match(wordPattern);
      if (wordMatch) {
        const word = wordMatch[0];
        let className = "";
        if (keywords.has(word)) {
          className = "tok-kw";
        } else if (lastWord === "func") {
          className = "tok-fn";
        } else if (builtinTypes.has(word) || /^[A-Z]/.test(word)) {
          className = "tok-type";
        }

        result += className
          ? `<span class="${className}">${escapeHTML(word)}</span>`
          : escapeHTML(word);
        index += word.length;
        lastWord = word;
        continue;
      }

      result += escapeHTML(character);
      if (!/\s/.test(character)) lastWord = "";
      index += 1;
    }

    return result;
  };

  document.querySelectorAll('code[data-highlight="swift"]').forEach((block) => {
    const source = block.textContent;
    block.innerHTML = highlightSwift(source);
  });

  // Code tabs and copy button
  const tabs = Array.from(document.querySelectorAll("[data-tab]"));
  const panels = Array.from(document.querySelectorAll("[data-panel]"));
  const copyButton = document.querySelector("[data-copy-button]");

  const activeCode = () => {
    const visiblePanel = panels.find((panel) => !panel.hidden);
    return visiblePanel ? visiblePanel.querySelector("code") : null;
  };

  const activateTab = (name) => {
    tabs.forEach((tab) => {
      const selected = tab.dataset.tab === name;
      tab.classList.toggle("active", selected);
      tab.setAttribute("aria-selected", String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    panels.forEach((panel) => {
      panel.hidden = panel.dataset.panel !== name;
    });
  };

  tabs.forEach((tab, index) => {
    tab.tabIndex = tab.classList.contains("active") ? 0 : -1;
    tab.addEventListener("click", () => activateTab(tab.dataset.tab));
    tab.addEventListener("keydown", (event) => {
      if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") return;
      event.preventDefault();
      const direction = event.key === "ArrowRight" ? 1 : -1;
      const nextIndex = (index + direction + tabs.length) % tabs.length;
      tabs[nextIndex].focus();
      activateTab(tabs[nextIndex].dataset.tab);
    });
  });

  const fallbackCopy = (text) => {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    document.execCommand("copy");
    area.remove();
  };

  if (copyButton) {
    copyButton.addEventListener("click", async () => {
      const code = activeCode();
      if (!code) return;
      const text = code.textContent;
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          fallbackCopy(text);
        }
        const label = copyButton.querySelector("span");
        if (label) {
          const previous = label.textContent;
          label.textContent = "Copied";
          copyButton.classList.add("copied");
          window.setTimeout(() => {
            label.textContent = previous;
            copyButton.classList.remove("copied");
          }, 1600);
        }
      } catch (error) {
        fallbackCopy(text);
      }
    });
  }

  // Screenshot lightbox
  const lightbox = document.getElementById("lightbox");
  const lightboxImage = lightbox ? lightbox.querySelector("img") : null;
  const lightboxClose = lightbox ? lightbox.querySelector(".lightbox-close") : null;

  document.querySelectorAll("[data-lightbox]").forEach((trigger) => {
    trigger.addEventListener("click", () => {
      if (!lightbox || !lightboxImage) return;
      const source = trigger.dataset.lightbox;
      const image = trigger.querySelector("img");
      lightboxImage.src = source;
      lightboxImage.alt = image ? image.alt : "SpecForge screenshot";
      if (typeof lightbox.showModal === "function") {
        lightbox.showModal();
      } else {
        window.open(source, "_blank", "noopener");
      }
    });
  });

  if (lightbox) {
    if (lightboxClose) lightboxClose.addEventListener("click", () => lightbox.close());
    lightbox.addEventListener("click", (event) => {
      if (event.target === lightbox) lightbox.close();
    });
    lightbox.addEventListener("close", () => {
      if (lightboxImage) lightboxImage.src = "";
    });
  }

  // Small live GitHub details, omitted gracefully when offline or rate-limited.
  // Skip the API calls during local previews so the console stays clean.
  const isLocalPreview = /^(127\.0\.0\.1|localhost|0\.0\.0\.0)$/.test(window.location.hostname);
  const starsElement = document.querySelector("[data-stars]");
  if (starsElement && !isLocalPreview) {
    fetch("https://api.github.com/repos/LBkos/specforge", {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then((response) => (response.ok ? response.json() : null))
      .then((data) => {
        if (!data || !Number.isFinite(data.stargazers_count) || data.stargazers_count <= 0) return;
        starsElement.textContent = `★ ${data.stargazers_count}`;
        starsElement.hidden = false;
      })
      .catch(() => {});
  }

  if (!isLocalPreview) {
    fetch("https://api.github.com/repos/LBkos/specforge/releases/latest", {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then((response) => (response.ok ? response.json() : null))
      .then((release) => {
        if (!release || !release.tag_name) return;
        document.querySelectorAll("[data-release-version]").forEach((element) => {
          element.textContent = release.tag_name.startsWith("v") ? release.tag_name : `v${release.tag_name}`;
        });
      })
      .catch(() => {});
  }

  document.querySelectorAll("[data-year]").forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });

  root.classList.add("js-ready");
})();
