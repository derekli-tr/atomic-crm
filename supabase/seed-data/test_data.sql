--
-- Test data: 10 companies, 15 contacts, 10 deals, 5 tasks.
--
-- Run with `make seed-test-data` AFTER the first user has signed up (the records
-- are owned by the first active administrator in `sales`).
--
-- Reproducible: every value (ids, dates, amounts) is fixed, so two databases
-- seeded with this file hold identical data.
-- Idempotent: records use reserved ids (9001+) and `on conflict (id) do update`,
-- so re-running never creates duplicates; it resets these records to the
-- baseline below (e.g. a deal moved to "won" goes back to its seeded stage).
-- Records created through the app keep their own ids and are never touched.
--
-- Avatars and logos are set explicitly (to the same favicon URL the save
-- triggers would compute) so seeding makes no network calls.
--

begin;

create temporary table seed_owner on commit drop as
select id from public.sales
where administrator and not disabled
order by id
limit 1;

do $$
begin
  if not exists (select 1 from seed_owner) then
    raise exception 'No administrator found in public.sales: sign up the first user in the app, then re-run the seed.';
  end if;
end;
$$;

--
-- Companies
--
insert into public.companies (id, created_at, name, sector, size, linkedin_url, website, phone_number, address, zipcode, city, state_abbr, country, description, revenue, sales_id, logo)
select c.id, c.created_at::timestamptz, c.name, c.sector, c.size, c.linkedin_url, c.website, c.phone_number, c.address, c.zipcode, c.city, c.state_abbr, 'United States', c.description, c.revenue, o.id,
       jsonb_build_object('src', 'https://favicon.show/' || c.website, 'title', 'Company favicon')
from seed_owner o, (values
  (9001, '2026-09-01 09:00:00+00', 'Northwind Logistics',       'industrials',            250::smallint, 'https://www.linkedin.com/company/northwind-logistics', 'northwindlogistics.com', '+1 312-555-0141', '400 W Lake St',        '60606', 'Chicago',     'IL', 'Regional freight and last-mile delivery operator.',           '$100M'),
  (9002, '2026-09-02 09:00:00+00', 'Bluepeak Software',         'information-technology', 50,            'https://www.linkedin.com/company/bluepeak-software',   'bluepeaksoftware.com',   '+1 512-555-0187', '901 Congress Ave',     '78701', 'Austin',      'TX', 'B2B SaaS for field-service scheduling.',                      '$10M'),
  (9003, '2026-09-03 09:00:00+00', 'Harbor Health Partners',    'health-care',            500,           'https://www.linkedin.com/company/harbor-health',       'harborhealthpartners.com','+1 617-555-0112', '75 Federal St',        '02110', 'Boston',      'MA', 'Network of outpatient clinics across New England.',           '$1B'),
  (9004, '2026-09-04 09:00:00+00', 'Greenfield Organics',       'consumer-staples',       50,            'https://www.linkedin.com/company/greenfield-organics', 'greenfieldorganics.com', '+1 503-555-0164', '1120 NW Couch St',     '97209', 'Portland',    'OR', 'Organic packaged foods sold in natural grocery chains.',      '$10M'),
  (9005, '2026-09-05 09:00:00+00', 'Summit Financial Group',    'financials',             250,           'https://www.linkedin.com/company/summit-financial',    'summitfinancialgroup.com','+1 212-555-0193', '250 Park Ave',         '10177', 'New York',    'NY', 'Wealth management and advisory firm.',                        '$100M'),
  (9006, '2026-09-06 09:00:00+00', 'Ironclad Manufacturing',    'materials',              500,           'https://www.linkedin.com/company/ironclad-mfg',        'ironcladmfg.com',        '+1 313-555-0128', '2000 Brush St',        '48226', 'Detroit',     'MI', 'Steel components for the automotive industry.',               '$1B'),
  (9007, '2026-09-07 09:00:00+00', 'Crescent Energy Solutions', 'energy',                 250,           'https://www.linkedin.com/company/crescent-energy',     'crescentenergy.com',     '+1 713-555-0175', '811 Main St',          '77002', 'Houston',     'TX', 'Commercial solar installation and energy storage.',           '$100M'),
  (9008, '2026-09-08 09:00:00+00', 'Lumen Media Studios',       'communication-services', 10,            'https://www.linkedin.com/company/lumen-media',         'lumenmediastudios.com',  '+1 323-555-0150', '6255 Sunset Blvd',     '90028', 'Los Angeles', 'CA', 'Independent video production studio.',                        '$1M'),
  (9009, '2026-09-09 09:00:00+00', 'Keystone Realty',           'real-estate',            10,            'https://www.linkedin.com/company/keystone-realty',     'keystonerealty.com',     '+1 303-555-0136', '1600 Glenarm Pl',      '80202', 'Denver',      'CO', 'Residential brokerage focused on the Denver metro area.',     '$1M'),
  (9010, '2026-09-10 09:00:00+00', 'Velo Outdoor Gear',         'consumer-discretionary', 50,            'https://www.linkedin.com/company/velo-outdoor',        'velooutdoorgear.com',    '+1 206-555-0119', '1501 4th Ave',         '98101', 'Seattle',     'WA', 'Direct-to-consumer cycling and hiking equipment.',            '$10M')
) as c(id, created_at, name, sector, size, linkedin_url, website, phone_number, address, zipcode, city, state_abbr, description, revenue)
on conflict (id) do update set
  created_at = excluded.created_at, name = excluded.name, sector = excluded.sector, size = excluded.size,
  linkedin_url = excluded.linkedin_url, website = excluded.website, phone_number = excluded.phone_number,
  address = excluded.address, zipcode = excluded.zipcode, city = excluded.city, state_abbr = excluded.state_abbr,
  country = excluded.country, description = excluded.description, revenue = excluded.revenue,
  sales_id = excluded.sales_id, logo = excluded.logo;

--
-- Contacts
--
insert into public.contacts (id, first_name, last_name, gender, title, background, company_id, email_jsonb, phone_jsonb, linkedin_url, status, has_newsletter, tags, first_seen, last_seen, sales_id, avatar)
select c.id, c.first_name, c.last_name, c.gender, c.title, c.background, c.company_id,
       jsonb_build_array(jsonb_build_object('email', c.email, 'type', 'Work')),
       jsonb_build_array(jsonb_build_object('number', c.phone, 'type', 'Work')),
       'https://www.linkedin.com/in/' || lower(c.first_name || '-' || c.last_name),
       c.status, c.has_newsletter, '{}'::bigint[], c.first_seen::timestamptz, c.last_seen::timestamptz, o.id,
       jsonb_build_object('src', 'https://favicon.show/' || split_part(c.email, '@', 2))
from seed_owner o, (values
  (9001, 'Olivia',   'Bennett',   'female',    'VP of Operations',         'Leads the dispatch modernization program.',   9001, 'olivia.bennett@northwindlogistics.com',  '+1 312-555-0142', 'warm',        true,  '2026-09-01 10:00:00+00', '2026-11-05 15:30:00+00'),
  (9002, 'Marcus',   'Reyes',     'male',      'IT Director',              'Owns vendor selection for internal tools.',   9001, 'marcus.reyes@northwindlogistics.com',    '+1 312-555-0143', 'cold',        false, '2026-09-03 10:00:00+00', '2026-10-20 11:00:00+00'),
  (9003, 'Priya',    'Natarajan', 'female',    'Head of Marketing',        'Driving the website relaunch for Q1.',        9002, 'priya.natarajan@bluepeaksoftware.com',   '+1 512-555-0188', 'hot',         true,  '2026-09-02 10:00:00+00', '2026-11-10 09:15:00+00'),
  (9004, 'Daniel',   'Kim',       'male',      'CTO',                      'Technical sign-off on all agency work.',      9002, 'daniel.kim@bluepeaksoftware.com',        '+1 512-555-0189', 'warm',        false, '2026-09-04 10:00:00+00', '2026-11-02 14:00:00+00'),
  (9005, 'Sarah',    'O''Connell','female',    'Chief Digital Officer',    'Sponsor of the patient portal project.',      9003, 'sarah.oconnell@harborhealthpartners.com','+1 617-555-0113', 'hot',         true,  '2026-09-03 10:00:00+00', '2026-11-11 16:45:00+00'),
  (9006, 'James',    'Whitaker',  'male',      'Procurement Manager',      'Runs the RFP process and contract terms.',    9003, 'james.whitaker@harborhealthpartners.com','+1 617-555-0114', 'in-contract', false, '2026-09-10 10:00:00+00', '2026-11-09 10:30:00+00'),
  (9007, 'Emily',    'Carter',    'female',    'Brand Manager',            'Responsible for packaging and print.',        9004, 'emily.carter@greenfieldorganics.com',    '+1 503-555-0165', 'warm',        true,  '2026-09-04 10:00:00+00', '2026-11-04 13:20:00+00'),
  (9008, 'Noah',     'Fischer',   'male',      'Founder & CEO',            'Final decision maker on budget.',             9004, 'noah.fischer@greenfieldorganics.com',    '+1 503-555-0166', 'cold',        false, '2026-09-12 10:00:00+00', '2026-10-15 17:00:00+00'),
  (9009, 'Grace',    'Liu',       'female',    'Director of Communications','Produces the annual report each spring.',    9005, 'grace.liu@summitfinancialgroup.com',     '+1 212-555-0194', 'hot',         true,  '2026-09-05 10:00:00+00', '2026-11-08 12:00:00+00'),
  (9010, 'Robert',   'Hayes',     'male',      'COO',                      'Approves spend above $25k.',                  9005, 'robert.hayes@summitfinancialgroup.com',  '+1 212-555-0195', 'warm',        false, '2026-09-15 10:00:00+00', '2026-11-01 09:45:00+00'),
  (9011, 'Alex',     'Morgan',    'nonbinary', 'Events Coordinator',       'Plans trade show presence for the year.',     9006, 'alex.morgan@ironcladmfg.com',            '+1 313-555-0129', 'cold',        false, '2026-09-06 10:00:00+00', '2026-10-28 15:10:00+00'),
  (9012, 'Hannah',   'Brooks',    'female',    'Investor Relations Lead',  'Needs a new investor-facing website.',        9007, 'hannah.brooks@crescentenergy.com',       '+1 713-555-0176', 'hot',         true,  '2026-09-07 10:00:00+00', '2026-11-10 11:30:00+00'),
  (9013, 'Diego',    'Alvarez',   'male',      'Creative Director',        'Long-time partner, values fast turnaround.',  9008, 'diego.alvarez@lumenmediastudios.com',    '+1 323-555-0151', 'in-contract', true,  '2026-09-08 10:00:00+00', '2026-11-06 18:00:00+00'),
  (9014, 'Megan',    'Sullivan',  'female',    'Managing Broker',          'Project paused until the new fiscal year.',   9009, 'megan.sullivan@keystonerealty.com',      '+1 303-555-0137', 'cold',        false, '2026-09-09 10:00:00+00', '2026-10-10 10:00:00+00'),
  (9015, 'Ethan',    'Park',      'male',      'Head of E-commerce',       'Looking to lift checkout conversion.',        9010, 'ethan.park@velooutdoorgear.com',         '+1 206-555-0120', 'warm',        true,  '2026-09-10 10:00:00+00', '2026-11-07 14:25:00+00')
) as c(id, first_name, last_name, gender, title, background, company_id, email, phone, status, has_newsletter, first_seen, last_seen)
on conflict (id) do update set
  first_name = excluded.first_name, last_name = excluded.last_name, gender = excluded.gender, title = excluded.title,
  background = excluded.background, company_id = excluded.company_id, email_jsonb = excluded.email_jsonb,
  phone_jsonb = excluded.phone_jsonb, linkedin_url = excluded.linkedin_url, status = excluded.status,
  has_newsletter = excluded.has_newsletter, tags = excluded.tags, first_seen = excluded.first_seen,
  last_seen = excluded.last_seen, sales_id = excluded.sales_id, avatar = excluded.avatar;

--
-- Deals (stage values come from defaultDealStages; "index" orders cards within a Kanban column).
-- Open deals in proposal-sent / in-negociation are the ones meant to be moved to "won" in tests.
--
insert into public.deals (id, name, company_id, contact_ids, categories, stage, description, amount, created_at, updated_at, archived_at, expected_closing_date, sales_id, index)
select d.id, d.name, d.company_id, d.contact_ids, array[d.category], d.stage, d.description, d.amount,
       d.created_at::timestamptz, d.created_at::timestamptz, null, d.closing::date, o.id, d.idx
from seed_owner o, (values
  (9001, 'Fleet tracking dashboard',     9001, array[9001, 9002]::bigint[], 'ui-design',      'opportunity',    'Real-time dashboard for dispatchers to track 300+ trucks.',  48000,  '2026-10-01 09:00:00+00', '2027-01-30', 0::smallint),
  (9002, 'Marketing website redesign',   9002, array[9003, 9004]::bigint[], 'website-design', 'proposal-sent',  'Full redesign of the marketing site ahead of a Q1 launch.',  32000,  '2026-10-02 09:00:00+00', '2026-12-15', 0),
  (9003, 'Patient portal UI',            9003, array[9005, 9006]::bigint[], 'ui-design',      'in-negociation', 'Design system and UI for the new patient self-service portal.', 125000, '2026-10-03 09:00:00+00', '2026-12-31', 0),
  (9004, 'Packaging print run',          9004, array[9007]::bigint[],       'print-project',  'proposal-sent',  'Print production for the spring granola packaging line.',   18500,  '2026-10-04 09:00:00+00', '2026-12-05', 1),
  (9005, 'Annual report copywriting',    9005, array[9009, 9010]::bigint[], 'copywriting',    'in-negociation', 'Copywriting and editing for the 2026 annual report.',       27000,  '2026-10-05 09:00:00+00', '2026-12-20', 1),
  (9006, 'Trade show booth graphics',    9006, array[9011]::bigint[],       'print-project',  'opportunity',    'Large-format booth graphics for three industry trade shows.', 15000, '2026-10-06 09:00:00+00', '2027-02-28', 1),
  (9007, 'Investor relations website',   9007, array[9012]::bigint[],       'website-design', 'in-negociation', 'New investor site with quarterly reporting section.',       64000,  '2026-10-07 09:00:00+00', '2026-12-10', 2),
  (9008, 'Brand copy refresh',           9008, array[9013]::bigint[],       'copywriting',    'won',            'Rewrite of the studio''s website and pitch deck copy.',    12000,  '2026-10-08 09:00:00+00', '2026-11-01', 0),
  (9009, 'Property listings site',       9009, array[9014]::bigint[],       'website-design', 'delayed',        'Listings website, paused until budget is renewed.',        22000,  '2026-10-09 09:00:00+00', '2027-03-31', 0),
  (9010, 'E-commerce checkout UX audit', 9010, array[9015]::bigint[],       'ui-design',      'proposal-sent',  'UX audit and redesign of the checkout funnel.',            38000,  '2026-10-10 09:00:00+00', '2026-12-18', 2)
) as d(id, name, company_id, contact_ids, category, stage, description, amount, created_at, closing, idx)
on conflict (id) do update set
  name = excluded.name, company_id = excluded.company_id, contact_ids = excluded.contact_ids,
  categories = excluded.categories, stage = excluded.stage, description = excluded.description,
  amount = excluded.amount, created_at = excluded.created_at, updated_at = excluded.updated_at,
  archived_at = excluded.archived_at, expected_closing_date = excluded.expected_closing_date,
  sales_id = excluded.sales_id, index = excluded.index;

--
-- Tasks (all open, fixed due dates)
--
insert into public.tasks (id, contact_id, type, text, due_date, done_date, sales_id, created_at)
select t.id, t.contact_id, t.type, t.text, t.due_date::timestamptz, null, o.id, t.created_at::timestamptz
from seed_owner o, (values
  (9001, 9003, 'call',      'Walk Priya through the website redesign proposal',       '2026-11-16 15:00:00+00', '2026-11-02 09:00:00+00'),
  (9002, 9005, 'meeting',   'Negotiation meeting on patient portal scope and pricing', '2026-11-18 14:00:00+00', '2026-11-03 09:00:00+00'),
  (9003, 9012, 'email',     'Send revised investor site estimate to Hannah',          '2026-11-17 10:00:00+00', '2026-11-04 09:00:00+00'),
  (9004, 9001, 'demo',      'Demo the fleet dashboard prototype to Olivia',           '2026-11-24 16:00:00+00', '2026-11-05 09:00:00+00'),
  (9005, 9013, 'thank-you', 'Send a thank-you note to Diego for the signed contract', '2026-11-20 09:00:00+00', '2026-11-06 09:00:00+00')
) as t(id, contact_id, type, text, due_date, created_at)
on conflict (id) do update set
  contact_id = excluded.contact_id, type = excluded.type, text = excluded.text, due_date = excluded.due_date,
  done_date = excluded.done_date, sales_id = excluded.sales_id, created_at = excluded.created_at;

commit;
