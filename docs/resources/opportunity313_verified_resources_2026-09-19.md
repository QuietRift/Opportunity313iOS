# Opportunity313 verified resource candidates

Verified September 19, 2026. This is a staging review, not authorization to
publish. Every fact below comes from an official provider or City of Detroit
page. Unknown values remain unknown rather than being inferred.

## Import rules

- Add a record to the live `opportunities` table only after confirming its exact
  session date, registration status, and location.
- Treat provider wording such as “dates subject to change” as a requirement to
  recheck the registration page immediately before publication.
- Use `gender_eligibility = all` only when the provider explicitly says boys and
  girls, co-ed, or otherwise confirms universal eligibility. Do not infer gender.
- Keep closed and sold-out programs in a watchlist, not in youth-facing results.
- Reverify evergreen programs at least every 90 days and dated programs within
  seven days of publication.
- The associated JSON file uses `null` for facts the source does not state. It
  should be validated against the production database constraints before import.

## Ready for final registration check

| Provider | Program | Ages/grades | Eligibility | Cost | Timing/status | Official source |
|---|---|---:|---|---:|---|---|
| Detroit Zoo | Zoo Tots: Animal Groups | Ages 2–3 | Not stated | $215 public / $165 member | Sep. 11–Oct. 30, 2026; fall registration stated open | [Detroit Zoo](https://detroitzoo.org/learn/youth/zoo-tots/) |
| Detroit Zoo | Zoo Tots: Animal Habitats | Ages 3–4 | Not stated | $230 public / $180 member | Sep. 10–Oct. 29, 2026; fall registration stated open | [Detroit Zoo](https://detroitzoo.org/learn/youth/zoo-tots/) |
| Detroit Zoo | Zoo Tots: Animals Around the World | Ages 3–4 | Not stated | $240 public / $190 member | Sep. 9–Oct. 28, 2026 Wednesday session; fall registration stated open | [Detroit Zoo](https://detroitzoo.org/learn/youth/zoo-tots/) |
| Detroit Public Library / ProjectArt | ProjectArt at Duffield | Ages 4–12 | Not stated | Free; materials included | Thursdays 5–6 p.m., late Sep. 2026–May 2027; registration stated open | [DPL](https://detroitpubliclibrary.org/news/projectart-2026) |
| Detroit Public Library / ProjectArt | ProjectArt at Lincoln | Ages 4–12 | Not stated | Free; materials included | Mondays 4:30–5:30 p.m.; first listed occurrence Sep. 28, 2026 | [DPL announcement](https://detroitpubliclibrary.org/news/projectart-2026), [event](https://detroitpubliclibrary.org/events/event/1998456588453) |
| Detroit Public Library / ProjectArt | ProjectArt Teens at Lincoln | Ages 13–18 | Not stated | Free; materials included | Saturdays 2–3 p.m., late Sep. 2026–May 2027; registration stated open | [DPL](https://detroitpubliclibrary.org/news/projectart-2026) |
| Detroit PAL | Little Sluggers Fall T-Ball Clinic | Ages 4–8 | Boys and girls | $35 | Sep. 14–Oct. 12, 2026; calendar says registration opened in August | [program](https://detroitpal.org/t-ball/), [2026 calendar](https://detroitpal.org/wp-content/uploads/2026/02/2026-Program-Calendar-2026-Website-Calendarwith-Ages.pdf) |
| Detroit PAL | Rec. Soccer League | Ages 8–12 | Boys and girls | $40 | Six-week fall season, Sep.–Oct.; registration link currently shown | [Detroit PAL](https://detroitpal.org/soccer/) |
| Detroit PAL | Girls Rec. Soccer League | Ages 8–12 | Girls only | $40 | Six-week fall season, Sep.–Oct.; registration link currently shown | [Detroit PAL](https://detroitpal.org/soccer/) |
| Detroit PAL | Little Hoopers | Ages 4–8 | Youth; gender not stated on program detail | $35 | Fall session in October; 2026 calendar lists Oct.–Nov. | [program](https://detroitpal.org/basketball/), [2026 calendar](https://detroitpal.org/wp-content/uploads/2026/02/2026-Program-Calendar-2026-Website-Calendarwith-Ages.pdf) |
| DAPCEP | Explorers Saturday Classes | Pre-K–3rd grade | Not stated | $100; limited scholarships | Eight Saturdays, Sep.–Nov.; registration link shown | [DAPCEP](https://www.dapcep.org/saturday-classes/) |
| DAPCEP | Pathfinders Saturday Classes | 4th–12th grade | Not stated | $25; limited scholarships | Six Saturdays, Oct.–Nov.; registration link shown | [DAPCEP](https://www.dapcep.org/saturday-classes/) |
| DAPCEP | START STEM & Trades Readiness Tracks | 11th–12th grade | Not stated | Not stated | Two-year curriculum; Fall 2026 enrollment opened Aug. 17 | [DAPCEP](https://www.dapcep.org/saturday-classes/) |
| College for Creative Studies | Youth Courses | Ages 8–13 | Open to all; provider does not state gender rules | Varies by course | Studio and digital courses; current course catalog linked | [CCS](https://www.ccsdetroit.edu/academics/precollege-continuing-studies/) |
| College for Creative Studies | Teen Courses | Ages 14–18 | Open to all; provider does not state gender rules | Varies by course | Art and design courses taught by CCS faculty; current catalog linked | [CCS](https://www.ccsdetroit.edu/academics/precollege-continuing-studies/) |
| College for Creative Studies | Adult Courses | Ages 16+ | Open to all; provider does not state gender rules | Varies by course | Non-degree art/design courses; current catalog linked | [CCS](https://www.ccsdetroit.edu/academics/precollege-continuing-studies/) |
| Detroit Public Library | HYPE Teen Center / HYPE Teen Card | Ages 13–18 | Not stated | Library access; no fee stated | Evergreen access program at Main Library | [DPL](https://detroitpubliclibrary.org/services/hype) |
| City of Detroit / Detroit at Work | Job, training, education and support services | Ages 18+ | Not stated | City page describes education/training support; individual costs not stated | Ongoing; nine career centers and phone support | [City of Detroit](https://detroitmi.gov/opportunities/jobs) |

## City and seasonal watchlist

These are real programs, but they should not be published as currently open
until the missing session data is verified.

| Provider | Program | Confirmed facts | Why watchlisted | Official source |
|---|---|---|---|---|
| City of Detroit / GOAL Line | 2026–27 after-school expansion | City announced 40 school, library, recreation-center, and partner sites, transportation, and expanded programming for DPSCD, charter, and homeschool students | Announcement does not provide participant ages, program-level schedules, or registration links | [City announcement](https://detroitmi.gov/news/mayor-sheffield-announces-historic-22m-funding-commitment-after-school-programming-detroit) |
| City of Detroit Parks & Recreation | Adams Butzel Fall 2026 programs | Fall schedule exists; center offers swimming, skating, basketball, field sports, and more; membership required and class fees may apply | Individual activity ages, prices, and times need extraction/confirmation from the current schedule | [City center page](https://detroitmi.gov/departments/detroit-parks-recreation/recreation-centers/adams-butzel-complex) |
| City of Detroit / GDYT | Grow Detroit’s Young Talent | Detroit residents ages 14–24; paid six-week summer work experience; up to 120 hours; DDOT access available with current program ID/shirt | 2026 application closed May 15; retain for the next annual cycle rather than publishing as open | [City announcement](https://detroitmi.gov/news/detroit-youth-can-now-register-summer-jobs-mayor-sheffield-announces-opening-2026-gdyt-application), [GDYT FAQ](https://www.gdyt.org/frequently-asked-questions/youth-and-parents) |
| City of Detroit / Occupy the Summer | Summer Fridays and extended recreation hours | City-operated events were free to registered participants; Summer Fridays were family-friendly; late-night basketball was 18+ and Detroit-resident-only | 2026 summer dates have passed | [City FAQ](https://ots.detroitmi.gov/faqs), [Summer Fridays](https://ots.detroitmi.gov/summer-fridays) |
| Michigan Science Center | 2026 Spark! Camps | Incoming K–1, grades 2–3, and grades 4–5; STEM camp themes and field trips | Official page says 2026 camps are sold out | [Michigan Science Center](https://www.mi-sci.org/learn/families/camps/) |
| DPSCD | Summer Discovery 2026 | Free for DPSCD students; Pre-K–8 academic/enrichment programming; transportation and meals; high-school credit recovery | Program ended July 24, 2026; retain as a future-cycle source | [DPSCD](https://www.detroitk12.org/families-students/summer-discovery-2026) |
| College for Creative Studies | 2026 summer scholarships | Ages 8–18; scholarships covered youth, teen, and precollege summer programs | Summer cycle has passed; monitor for 2027 | [CCS](https://www.ccsdetroit.edu/academics/precollege-continuing-studies/) |

## Coverage summary

- Ages 2–4: Detroit Zoo caregiver programs.
- Ages 4–8: ProjectArt, PAL T-ball and basketball, DAPCEP Explorers.
- Ages 8–13: ProjectArt, PAL soccer, DAPCEP, CCS Youth Courses.
- Ages 13–18: ProjectArt Teens, HYPE, DAPCEP, CCS Teen Courses.
- Ages 18–24: CCS Adult Courses, Detroit at Work; GDYT retained for its next cycle.

## Important data decisions

- The public non-member Detroit Zoo price is used as the candidate `cost_cents`;
  member pricing belongs in `schedule_note` or a future pricing-details field.
- ProjectArt classes are separate records by branch/age band because their times,
  locations, and eligibility differ.
- PAL girls-only soccer must use `gender_eligibility = girls`. PAL programs that
  explicitly say boys and girls can use `all`; ambiguous “youth” wording remains
  `null` until confirmed.
- Recurring/evergreen catalogs such as CCS should eventually be represented as
  individual course records, not one broad listing, once the current course
  catalog is ingested.
- City announcements are valid first-party sources, but announcements without
  program-level enrollment details stay in the watchlist.

