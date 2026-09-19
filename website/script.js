const profiles = {
  child: {
    name: "Jordan",
    filter: "Age 8 · All genders",
    opportunities: [
      { category: "LEARNING · FREE", title: "Junior Science Explorers", meta: "Ages 7–9 · Midtown", image: "learning.jpg" },
      { category: "SPORTS · EQUIPMENT PROVIDED", title: "Saturday Soccer Skills", meta: "Ages 6–10 · Southwest Detroit", image: "sports.jpg" },
    ],
  },
  teen: {
    name: "Amari",
    filter: "Age 15 · Girls",
    opportunities: [
      { category: "TECHNOLOGY · FREE", title: "Teen Coding Studio", meta: "Ages 14–17 · Downtown", image: "technology.jpg" },
      { category: "ARTS · APPLICATION OPEN", title: "Young Creators Collective", meta: "Grades 9–12 · Cultural Center", image: "arts.jpg" },
    ],
  },
  adult: {
    name: "Taylor",
    filter: "Age 21 · Independent",
    opportunities: [
      { category: "SKILLED TRADES · PAID", title: "Green Careers Pre-Apprenticeship", meta: "Ages 18–24 · Detroit", image: "technology.jpg" },
      { category: "CULINARY · CERTIFICATE", title: "Hospitality Career Launch", meta: "Ages 18–24 · New Center", image: "culinary.jpg" },
    ],
  },
};

const grid = document.querySelector("#opportunity-grid");
const kicker = document.querySelector("#profile-kicker");
const filterBadge = document.querySelector("#filter-badge");

function renderProfile(profileKey) {
  const profile = profiles[profileKey];
  kicker.textContent = `Showing opportunities for ${profile.name}`;
  filterBadge.textContent = profile.filter;
  grid.innerHTML = profile.opportunities.map((item) => `
    <article class="opportunity-card">
      <img src="/images/${item.image}" alt="" />
      <div class="card-body">
        <small>${item.category}</small>
        <h4>${item.title}</h4>
        <p>${item.meta}</p>
      </div>
    </article>
  `).join("");
}

document.querySelectorAll(".profile-chip").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".profile-chip").forEach((chip) => {
      chip.classList.remove("active");
      chip.setAttribute("aria-pressed", "false");
    });
    button.classList.add("active");
    button.setAttribute("aria-pressed", "true");
    renderProfile(button.dataset.profile);
  });
});

document.querySelectorAll("[data-theme-preview]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-theme-preview]").forEach((control) => control.classList.remove("active"));
    button.classList.add("active");
    const surface = document.querySelector("#preview-surface");
    surface.classList.toggle("dark", button.dataset.themePreview === "dark");
    surface.classList.toggle("light", button.dataset.themePreview === "light");
  });
});

const menuButton = document.querySelector(".menu-button");
const mobileNav = document.querySelector("#mobile-nav");
menuButton.addEventListener("click", () => {
  const isOpen = menuButton.getAttribute("aria-expanded") === "true";
  menuButton.setAttribute("aria-expanded", String(!isOpen));
  mobileNav.hidden = isOpen;
});
mobileNav.querySelectorAll("a").forEach((link) => link.addEventListener("click", () => {
  menuButton.setAttribute("aria-expanded", "false");
  mobileNav.hidden = true;
}));

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add("visible");
      observer.unobserve(entry.target);
    }
  });
}, { threshold: 0.12 });
document.querySelectorAll(".reveal").forEach((element) => observer.observe(element));

document.querySelector("#year").textContent = new Date().getFullYear();
renderProfile("child");

