"""Project B: 5-section SQL-backed Streamlit dashboard. No pandas aggregation."""
import streamlit as st
import altair as alt
from db_dashboard import run_query, rollback_delete_demo, fetch_filters, QUERIES

st.set_page_config(page_title="Developer Trust in AI | Project B", page_icon="✦", layout="wide", initial_sidebar_state="collapsed")

# Visual language:
# ultramarine + saturated violet, airy lilac/ice-blue surfaces, fine rules,
# numbered circles, and restrained iridescent accents.
st.markdown("""<style>
@import url('https://fonts.googleapis.com/css2?family=Source+Sans+Pro:wght@400;600;700&display=swap');
:root { --azure:#1768f4; --violet:#4459e8; --navy:#143783; --ink:#17396a; --pale:#e9f3ff; }
html, body, [class*='css'], [data-testid='stAppViewContainer'] { font-family: 'Source Sans Pro', sans-serif!important; font-weight:400; }
.stApp {background: linear-gradient(120deg,#eaf3ff 0%,#dcecff 49%,#ecf6ff 100%) fixed; color:var(--ink);}
[data-testid='stHeader'] {background:transparent;}
[data-testid='stSidebar'], [data-testid='collapsedControl'] {display:none;}
.block-container {max-width: 1380px; padding-top: 1.3rem; padding-bottom:4rem;}
h1,h2,h3 {font-family:'Source Sans Pro',sans-serif!important; font-weight:600!important; letter-spacing:.01em; color:var(--azure)!important;}
h2 {font-size:2.8rem!important; margin-top:.9rem!important;}
h3 {font-size:1.8rem!important;}
p,li,[data-testid='stMarkdownContainer'] {color:var(--ink);}
.hero {position:relative; overflow:hidden; min-height:218px; border-radius:4px;
  padding:29px 38px 31px; isolation:isolate; background:linear-gradient(110deg,#2746cc 0%,#295dea 48%,#0d88e5 100%);
  box-shadow:0 13px 38px rgba(63,64,160,.13); margin-bottom:18px;}
.hero::before {content:''; position:absolute; width:370px;height:370px; border-radius:46% 54% 70% 30%;
  top:-190px;right:115px; transform:rotate(29deg); opacity:.7; z-index:-1;
  background:conic-gradient(from 50deg,#91fff4,#ffb5ea,#ba92ff,#b2fff6,#6497ff,#91fff4);
  filter:blur(34px);}
.hero::after {content:'';position:absolute;width:320px;height:300px;border-radius:50%;right:-76px;bottom:-160px;
 background:radial-gradient(circle at 40% 30%,#fbd3fe 0%,#53e9ef 35%,#4564f2 70%,transparent 83%);
 filter:blur(30px); opacity:.77;z-index:-1;}
.hero-rule {border-top:1px solid rgba(255,255,255,.7);width:100%;margin:8px 0 27px;}
.hero-kicker {color:white;font-size:12px;letter-spacing:.2em;text-transform:uppercase;font-weight:600;}
.hero-title {font-family:'Source Sans Pro',sans-serif;font-size:clamp(39px,4.3vw,65px);line-height:.96;
  color:white;letter-spacing:.01em;font-weight:500;margin:0 0 12px;max-width:850px;}
.hero-subtitle {color:#f1e9ff;font-size:14px;margin:0;}
.hero-authors {position:absolute;right:34px;bottom:29px;text-align:right;color:white;font-size:14px;line-height:1.45;font-weight:600;z-index:2;}
@media(max-width:850px){.hero-authors{position:static;text-align:right;margin-top:17px}}
.nav-overline {color:var(--violet);text-transform:uppercase;letter-spacing:.16em;font-weight:700;font-size:11px;margin:21px 0 3px;}
/* Horizontal, persistent navigation: use Streamlit's built-in accessible radio control. */
.st-key-top_navigation [role='radiogroup'] {display:flex;flex-wrap:wrap;gap:8px;padding:7px;
  border-radius:17px;background:#f8fbffed;border:1px solid #c6ddfc;box-shadow:0 6px 23px #312a7c08;}
.st-key-top_navigation [data-testid='stRadio'] label {margin:0!important;}
.st-key-top_navigation [role='radiogroup'] label {background:#e6f1ff;border:1px solid #c9defa;
 border-radius:10px;padding:10px 15px!important;transition:background .2s;}
.st-key-top_navigation [role='radiogroup'] label:has(input:checked) {background:linear-gradient(105deg,#2655db,#1788eb);border-color:transparent;}
.st-key-top_navigation [role='radiogroup'] label:has(input:checked) p {color:white!important;font-weight:700;}
.st-key-top_navigation [role='radiogroup'] label>div:first-child {display:none!important;}
.st-key-top_navigation [role='radiogroup'] p {font-size:13px!important;color:#344078!important;}
[data-testid='stTabs'] [role='tablist'] {border-bottom:1px solid #bad4f6;gap:8px;flex-wrap:wrap;}
[data-testid='stTabs'] [role='tab'] {color:#46428d!important; border-radius:8px 8px 0 0;}
[data-testid='stTabs'] [role='tab'][aria-selected='true'] {color:var(--azure)!important;border-bottom:3px solid var(--azure)!important;}
[data-testid='stMetric'] {background:#f4f9ff;border:1px solid #c9def8;border-radius:12px;padding:14px;}
[data-testid='stMetricValue'] {color:var(--azure);}
.stButton button[kind='primary'], .stButton button {border-color:#a995e8;color:#3d31a0;border-radius:10px;}
.stButton button[kind='primary']:hover,.stButton button:hover {border-color:var(--violet);color:var(--violet);}
[data-testid='stDataFrame'],[data-testid='stVegaLiteChart'] {border:1px solid #c2daf7;border-radius:12px;overflow:hidden;}
[data-testid='stExpander'] {background:#f4f9ff;border:1px solid #c3d9fa;border-radius:12px;}
[data-testid='stCaptionContainer'] {color:#71739d!important;}

/* Airier blue surfaces and readable typography for Streamlit widgets. */
[data-testid='stVerticalBlockBorderWrapper'] > div {border-color:#bfdafa;}
[data-testid='stSelectbox'],[data-testid='stMultiSelect'],[data-testid='stNumberInput'] {color:#17396a;}
[data-testid='stTabs'] {background:transparent;}
[data-testid='stTabs'] [role='tabpanel'] {background:#f4f9ffbc; border:1px solid #d0e3fa; border-radius:14px; padding:19px 22px;}
[data-testid='stSlider'] {accent-color:#1976e6;}
[data-testid='stAlert'] {border-radius:12px;}
.st-key-top_navigation {margin-bottom:14px;}
[data-testid='stMarkdownContainer'] p {line-height:1.52;}
.query-author {color:#2056b1;font-size:14px;font-weight:600;margin-bottom:16px;}
.page-footer {margin-top:56px;padding:17px 0 0;border-top:1px solid #aac9ef;color:#7776a5;font-size:11px;}
@media(max-width:850px) {.hero{padding:20px;min-height:170px}.hero-title{font-size:48px}.block-container{padding-left:1rem;padding-right:1rem;}}
</style>""", unsafe_allow_html=True)

st.markdown("""<section class='hero'>
  <div class='hero-kicker'>Information Technology &nbsp; / &nbsp; Project B</div>
  <div class='hero-rule'></div>
  <div class='hero-title'>Developer Trust<br>in Artificial Intelligence</div>
  <p class='hero-subtitle'>Stack Overflow Developer Survey 2026</p>
  <div class='hero-authors'>Ainhoa Gibaja<br>Ana Caro Casares</div>
</section>""", unsafe_allow_html=True)


from csv import DictWriter
from io import StringIO
from numbers import Number
import plotly.graph_objects as go
import re

# Mirror the questions agreed by the team (report, Section 5).
QUESTIONS = {
  1: 'How are respondents distributed across a demographic of the user’s choice?',
  2: 'What does the full record of one specific respondent look like?',
  3: 'How many respondents gave each level of trust?',
  4: 'What is the average trust for each job role?',
  5: 'How far is each role’s average trust from the overall average?',
  6: 'How does average trust change across experience buckets?',
  7: 'After classifying respondents as low, medium, or high trust, how many fall into each segment by role or experience?',
  8: "What share of each language's users also used AI tools with it, and how do languages rank by that share?",
  9: "Which AI tools are used by more than N respondents, and what is their users' average trust?",
  10: 'Which respondents delegated more kinds of tasks to AI agents than the average responder to that question, and what is their role?',
  11: 'Do respondents who use AI for longer times daily tend to trust it more or less?',
  12: 'Which databases are used by at least N respondents, and what share of users want to keep using them?',
  13: 'Which respondents use more programming languages than the average responder to that question?',
  14: 'How do programming languages rank within each country?',
  15: 'Can we delete a respondent from our database with only one transaction?',
}
ADVANCED={5,6,7,8,10,11,13,14}
AUTHORS={1:'Ainhoa',2:'Ana Caro',3:'Ainhoa',4:'Ana Caro',5:'Ana Caro',6:'Ainhoa',
         7:'Ainhoa',8:'Ainhoa',9:'Ana Caro',10:'Ainhoa',11:'Ana Caro',12:'Ainhoa',
         13:'Ana Caro',14:'Ana Caro',15:'Ana Caro'}
SECTIONS=['Respondents','Trust in AI','AI Adoption and Usage','Technology Landscape','Data Maintenance']
BLUE='#1768F4'; NAVY='#143783'; CYAN='#0C9CE5'; PALE='#DBEAFE'; PURPLE='#6366F1'
CHART_SCALE=alt.Scale(range=[BLUE,CYAN,PURPLE,'#64B5F6','#1D4ED8','#99C5F8'])

st.markdown("<div class='nav-overline'>Explore / Select a topic</div>",unsafe_allow_html=True)
section=st.radio('Select topic',SECTIONS,horizontal=True,key='top_navigation',label_visibility='collapsed')


@st.cache_data(ttl=300)
def filters():
    return fetch_filters()

try:
    options=filters()
except Exception as ex:
    st.error(f'Unable to connect to PostgreSQL: {ex}')
    st.stop()

with st.expander('Optional demographic filters',expanded=False):

    c1,c2,c3=st.columns(3)
    with c1: countries=st.multiselect('Countries',options['countries'])
    with c2: roles=st.multiselect('Job roles',options['roles'])
    with c3: age_groups=st.multiselect('Age groups',options['age_groups'])
    c4,c5=st.columns(2)
    with c4: min_years=st.number_input('Minimum years coding',min_value=0,max_value=100,value=0)
    with c5: max_years=st.number_input('Maximum years coding',min_value=0,max_value=100,value=100)
P={'countries':countries or None,'roles':roles or None,'age_groups':age_groups or None,
   'min_years':min_years if min_years>0 else None,'max_years':max_years if max_years<100 else None,
   'min_users':20,'min_resp':20,'top_n':5,'respondent_id':options['example_respondent']}

def fetch(name,**overrides):
    try:
        return run_query(name,{**P,**overrides})
    except Exception as ex:
        st.error(f'{name}: {ex}')
        return None

def tooltips(rows):
    if not rows:return []
    return [alt.Tooltip(field=k,type='quantitative' if any(isinstance(r.get(k),Number) and
                not isinstance(r.get(k),bool) for r in rows) else 'nominal') for k in rows[0]]

def heading(n):
    st.subheader(f'Q{n}. {QUESTIONS[n]}')
    st.markdown(f"<div class='query-author'>{AUTHORS[n]}</div>", unsafe_allow_html=True)

def source_below_chart(name, respondent_id=None):
    """Display the SQL query after the visualization, with Respondent ID option for Q15."""
    st.markdown('**SQL query**')
    try:
        sql = (QUERIES/name).read_text(encoding='utf-8-sig')

        if respondent_id is not None:
            sql = sql.replace('12345', str(int(respondent_id)))

        st.code(sql, language='sql')

    except OSError as ex:
        st.error(f'Cannot display SQL: {ex}')

def results(rows, max_rows=300, name='query'):
    if rows is None:return
    st.markdown('**Result sample**')
    if not rows:
        st.info('No records match these selections.')
        return

    st.dataframe(rows[:max_rows],use_container_width=True,hide_index=True)
    sink=StringIO()
    writer=DictWriter(sink,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    st.download_button('Download query result as CSV',data=sink.getvalue(),
                       file_name=f'{name.replace(".sql", "")}_results.csv',mime='text/csv',key=f'csv_{name}')

def alt_chart(chart):
    st.altair_chart(chart.configure_axis(labelColor=NAVY,titleColor=NAVY,gridColor='#d5e5fb')
                    .configure_view(stroke=None),use_container_width=True)

def category_sort_order(rows, field, *, semantic=None):
    """Return a natural numerical/ordinal sort for discrete chart categories.

    Nominal fields (e.g., countries and programming languages) retain the
    existing frequency ordering. Works with PostgreSQL int/Decimal and text
    labels, without pandas or client-side aggregation.
    """
    if not rows:
        return None
    categories = list(dict.fromkeys(r.get(field) for r in rows if r.get(field) is not None))
    if not categories:
        return None
    mode = semantic or field
    age_order = [
        'Under 18 years old', '18-24 years old', '25-34 years old',
        '35-44 years old', '45-54 years old', '55-64 years old',
        '65 years or older', 'Prefer not to say',
    ]
    so_order = [
        "I don't use Stack Overflow", 'Less than one year',
        'Between 1 and 3 years', 'Between 3 and 5 years',
        'Between 5 and 10 years', 'Between 10 and 15 years',
        'More than 15 years, or since Stack Overflow started in 2008',
    ]
    bucket_order = ['0-4 years', '5-9 years', '10-19 years', '20-29 years', '30+ years']
    if mode in ('age_group', 'Age group'):
        return sorted(categories, key=lambda x: (0, age_order.index(str(x))) if str(x) in age_order else (1, str(x)))
    if mode in ('so_years', 'Stack Overflow years'):
        return sorted(categories, key=lambda x: (0, so_order.index(str(x))) if str(x) in so_order else (1, str(x)))
    if mode in ('bucket', 'Coding experience'):
        return sorted(categories, key=lambda x: (0, bucket_order.index(str(x))) if str(x) in bucket_order else (1, str(x)))
    if all(isinstance(x, Number) and not isinstance(x, bool) for x in categories):
        return sorted(categories)
    if all(re.fullmatch(r'\s*[+-]?\d+(?:\.\d+)?\s*', str(x)) for x in categories):
        return sorted(categories, key=lambda x: float(x))
    # Numerical ranges (e.g. '25-34 years old' or '10-19 years')
    # are sorted by their lower bound, with 'Under' first and unknowns last.
    if all(re.search(r'\d+', str(x)) or str(x).lower().startswith(('under ', 'less than ', 'prefer not')) for x in categories) and mode in ('years_coding', 'Years coding', 'age_group', 'Age group', 'bucket'):
        def lower_bound(x):
            text = str(x).lower()
            if text.startswith(('under ', 'less than ')):
                return (-1, 0)
            if text.startswith('prefer not'):
                return (1, 0)
            match = re.search(r'\d+', text)
            return (0, int(match.group())) if match else (1, 0)
        return sorted(categories, key=lower_bound)
    return None


def bar(rows,x,y,caption='',limit=25,kind='bar',height=380,ordered_values=None,ymax=None):
    if rows is None or not rows:return
    values=rows[:limit]
    # Preserve ascending numerical/category order even if SQL rows were
    # initially ordered by descending respondent count.
    category_order = ordered_values if ordered_values is not None else category_sort_order(values, x)
    xenc=alt.X(f'{x}:O' if category_order is not None else f'{x}:N',
               sort=category_order if category_order is not None else ('-y' if kind=='bar' else None),
               title=x.replace('_',' ').title())
    y_scale = alt.Scale(domain=[0, ymax]) if ymax is not None else alt.Scale(zero=True)
    base=alt.Chart(alt.Data(values=values)).encode(
        x=xenc,y=alt.Y(f'{y}:Q',scale=y_scale,title=y.replace('_',' ').title()),tooltip=tooltips(values))
    chart=(base.mark_bar(cornerRadiusTopLeft=4,cornerRadiusTopRight=4)
           .encode(color=alt.condition(alt.datum[y] < 0,alt.value('#DA3545'),alt.value(BLUE)))
           .properties(height=height))

    alt_chart(chart)

def line(rows,x,y,order=None,zero=False,ymax=None):
    if rows is None or not rows:return
    # Discrete ordered buckets and usage categories preserve the ORDER BY in SQL.
    sort=(category_sort_order(rows, x) or list(dict.fromkeys(r[x] for r in rows))) if order is None else order
    scale_options = {'zero': zero}
    if zero:
        scale_options['domainMin'] = 0
    if ymax is not None:
        scale_options['domainMax'] = ymax
    chart=(alt.Chart(alt.Data(values=rows)).mark_line(point=alt.OverlayMarkDef(size=85),
              color=BLUE,strokeWidth=3).encode(
              x=alt.X(f'{x}:N',sort=sort,title=x.replace('_',' ').title()),
              y=alt.Y(f'{y}:Q',scale=alt.Scale(**scale_options),title=y.replace('_',' ').title()),
              tooltip=tooltips(rows)).properties(height=365))
    alt_chart(chart)

def pie(rows,labels,values,max_categories=12,height=380):
    if rows is None or not rows:return
    if len(rows)>max_categories:

        bar(rows,labels,values)
        return
    chart=(alt.Chart(alt.Data(values=rows)).mark_arc(innerRadius=62,outerRadius=147).encode(
        theta=alt.Theta(f'{values}:Q'),color=alt.Color(f'{labels}:N',scale=CHART_SCALE),
        tooltip=tooltips(rows)).properties(height=380))
    alt_chart(chart)

def scatter(rows,x,y,size=None,limit=150):
    if rows is None or not rows:return
    values=rows[:limit]
    enc={'x':alt.X(f'{x}:Q',scale=alt.Scale(zero=False),title=x.replace('_',' ').title()),
         'y':alt.Y(f'{y}:Q',scale=alt.Scale(zero=False),title=y.replace('_',' ').title()),
         'tooltip':tooltips(values)}
    if size:enc['size']=alt.Size(f'{size}:Q',scale=alt.Scale(range=[60,750]))
    chart=alt.Chart(alt.Data(values=values)).mark_circle(color=BLUE,opacity=.75).encode(**enc).properties(height=395)
    alt_chart(chart)

def labeled_scatter(rows, x, y, label, size=None, max_points=35, color_title=None, ymax=None):
    """Plotly scatter with labels and quantitative color hue; data already aggregated by SQL."""
    if not rows:
        return
    # Show highest-volume points by default; preserve one row per SQL result.
    all_points = [r for r in rows if r.get(x) is not None and r.get(y) is not None]
    if not all_points:
        return
    max_allowed = min(len(all_points), 100)
    default = min(max_points, max_allowed)
    show_n = st.slider('Number of labeled points', min_value=1,
                       max_value=max_allowed, value=default,
                       key=f'labeled_{x}_{y}_{label}') if max_allowed > 1 else 1
    display_rows = sorted(all_points, key=lambda r: float(r.get(size or x) or 0), reverse=True)[:show_n]
    labels = [str(r.get(label) or 'Unknown') for r in display_rows]
    sizes = [float(r.get(size or x) or 0) for r in display_rows]
    # Marker size uses area with bounded scaling to prevent obscuring the labels.
    maximum = max(sizes) if sizes else 1
    diameters = [12 + 24 * ((v / maximum) ** .5 if maximum > 0 else 0) for v in sizes]
    fig = go.Figure(go.Scatter(
        x=[float(r[x]) for r in display_rows],
        y=[float(r[y]) for r in display_rows],
        text=labels,
        mode='markers+text',
        textposition='top center',
        textfont=dict(size=10, color=NAVY),
        marker=dict(size=diameters, color=[float(r[y]) for r in display_rows],
                    colorscale=[[0,'#BFE9FF'],[.45,'#3D97F5'],[1,'#3440BB']],
                    showscale=True, colorbar=dict(title=color_title or y.replace('_',' ').title()),
                    line=dict(color='#ffffff',width=1), opacity=.85),
        customdata=[[r.get(label),r.get(size or x)] for r in display_rows],
        hovertemplate=f'%{{customdata[0]}}<br>{x}: %{{x:,.2f}}<br>{y}: %{{y:,.2f}}'
                      + (f'<br>{size}: %{{customdata[1]}}' if size else '')+'<extra></extra>',
    ))
    fig.update_layout(height=530,margin=dict(l=15,r=20,t=50,b=40),
                      paper_bgcolor='rgba(0,0,0,0)',plot_bgcolor='#f6faff',
                      font=dict(family='Source Sans Pro',color=NAVY),
                      xaxis=dict(title=x.replace('_',' ').title(),gridcolor='#d4e5f9',zerolinecolor='#accdf2'),
                      yaxis=dict(title=y.replace('_',' ').title(),gridcolor='#d4e5f9',zerolinecolor='#accdf2',
                                 **({'range':[0,ymax]} if ymax is not None else {})))
    st.plotly_chart(fig,use_container_width=True)



def readable_respondent_profile(rows, grouped_rows):
    """Show original respondent metadata and SQL-grouped answers, without Python aggregation."""
    if not rows:
        st.info('No respondent information was found for this ID.')
        return
    record = rows[0]
    st.markdown('**Respondent summary**')
    identity = [('Respondent ID', 'respondent_id'), ('Age group', 'age_group'),
                ('Gender', 'gender'), ('Country', 'country'), ('Education', 'education'),
                ('Coder type', 'coder_type'), ('Job role', 'role'), ('Industry', 'industry'),
                ('Organization size', 'org_size')]
    summary = [{'Field': title, 'Value': str(record[key])} for title, key in identity
               if record.get(key) is not None and str(record[key]).strip()]
    st.dataframe(summary, use_container_width=True, hide_index=True)
    st.markdown('**Recorded answers grouped by question**')
    if grouped_rows is None:
        st.error('The SQL aggregation query could not be executed.')
    elif not grouped_rows:
        st.info('No non-empty answers are recorded for this respondent.')
    else:
        # PostgreSQL performs DISTINCT, STRING_AGG, GROUP BY, and ORDER BY.
        st.dataframe(grouped_rows, use_container_width=True, hide_index=True)

def map_countries(rows,country_col,value_col,caption=''):
    """Country-name choropleth: uses Plotly's geographic dataset, no geocoding or personal location."""
    if rows is None or not rows:return
    values=[r for r in rows if r.get(country_col) and isinstance(r.get(value_col),Number)]
    if not values:return

    fig=go.Figure(go.Choropleth(locations=[r[country_col] for r in values],
           z=[r[value_col] for r in values],locationmode='country names',
           colorscale=[[0,'#d9edff'],[.4,'#69acf4'],[1,'#1846b3']],
           marker_line_color='#ffffff',marker_line_width=.5,
           colorbar_title=value_col.replace('_',' ').title(),
           customdata=[r[country_col] for r in values],
           hovertemplate='%{customdata}<br>Count: %{z:,.0f}<extra></extra>'))
    fig.update_geos(showframe=False,showcoastlines=True,coastlinecolor='#a9cbea',
                    showland=True,landcolor='#eaf3ff',bgcolor='rgba(0,0,0,0)',projection_type='natural earth')
    fig.update_layout(height=440,margin=dict(l=2,r=2,t=8,b=3),paper_bgcolor='rgba(0,0,0,0)',
                      font=dict(family='Source Sans Pro',color=NAVY),geo=dict(bgcolor='rgba(0,0,0,0)'))
    st.plotly_chart(fig,use_container_width=True)


if section=='Respondents':
    st.header('Respondents')
    t1,t2=st.tabs(['Q1 · Demographics','Q2 · Individual profile'])
    with t1:
        heading(1)
        allowed={'Age group':'age_group','Gender':'gender','Country':'country','Education':'education',
                 'Coder type':'coder_type','Stack Overflow account':'so_account',
                 'Stack Overflow years':'so_years','Years coding':'years_coding'}
        selected=st.selectbox('Choose a demographic',list(allowed))
        try:rows=run_query('01_demographic.sql',P,dimension=allowed[selected])
        except Exception as ex:st.error(str(ex));rows=None
        if selected=='Country':
            map_countries(rows,'category','respondents','Geographic distribution of respondents')
            with st.expander('View country comparison bars'):
                bar(rows,'category','respondents',limit=20)
        elif selected in {'Gender','Coder type'}:
            pie(rows,'category','respondents')
        else:
            bar(rows,'category','respondents',limit=30,
                ordered_values=category_sort_order(rows, 'category', semantic=selected))
        source_below_chart('01_demographic.sql');results(rows,name='01_demographic.sql')
    with t2:
        heading(2)
        rid=st.number_input('Respondent ID',min_value=1,value=int(options['example_respondent']),step=1)
        rows=fetch('02_respondent_profile.sql',respondent_id=int(rid)) if st.button('Load individual responses') else None
        if rows is not None:
            readable_rows=fetch('02_respondent_answers_readable.sql',respondent_id=int(rid))
            readable_respondent_profile(rows, readable_rows)
        source_below_chart('02_respondent_profile.sql')
        with st.expander('SQL helper used for readable answers'):
            st.code((QUERIES/'02_respondent_answers_readable.sql').read_text(encoding='utf-8'),language='sql')
        if rows is not None:
            with st.expander('Original SQL result · all rows and nullable fields'):
                results(rows,max_rows=1200,name='02_respondent_profile.sql')

elif section=='Trust in AI':
    st.header('Trust in AI')
    t3,t4,t5,t6,t7=st.tabs(['Q3 · Levels','Q4 · Roles','Q5 · Deviations','Q6 · Experience','Q7 · Segments'])
    with t3:
        heading(3);rows=fetch('03_trust_distribution.sql')
        c1,c2=st.columns([1,1],vertical_alignment='top')
        with c1:
            st.markdown('**Share of trust responses**')
            pie(rows,'trust_score','respondents',height=380)
        with c2:
            st.markdown('**Number of respondents by trust level**')
            bar(rows,'trust_score','respondents',limit=6,height=380,ordered_values=[0,1,2,3,4])
        source_below_chart('03_trust_distribution.sql');results(rows,name='03_trust_distribution.sql')
    with t4:
        heading(4);rows=fetch('04_role_trust.sql')
        bar(rows,'role','avg_trust',ymax=4);source_below_chart('04_role_trust.sql');results(rows,name='04_role_trust.sql')
    with t5:
        heading(5);n=st.slider('Minimum respondents per role',5,500,20)
        rows=fetch('05_role_vs_overall.sql',min_resp=n)
        bar(rows,'role','difference',limit=30)

        source_below_chart('05_role_vs_overall.sql');results(rows,name='05_role_vs_overall.sql')
    with t6:
        heading(6);rows=fetch('06_experience_buckets.sql')
        line(rows,'bucket','avg_trust',zero=True,ymax=4)
        source_below_chart('06_experience_buckets.sql');results(rows,name='06_experience_buckets.sql')
    with t7:
        heading(7)
        mode=st.radio('Group by',['Job role','Coding experience'],horizontal=True)
        sqlname='07_trust_segments_role.sql' if mode=='Job role' else '07_trust_segments_experience.sql'
        rows=fetch(sqlname)
        if rows:
            if 'grouping' not in rows[0]:
                st.error('Q7 SQL output is missing the grouping column. Replace dashboard_queries/07_trust_segments_experience.sql with the supplied corrected SQL, then rerun the page.')
            else:
                if mode == 'Coding experience':
                    ordered=['0-4 years','5-9 years','10-19 years','20-29 years','30+ years']
                else:
                    ordered=list(dict.fromkeys(r['grouping'] for r in rows))
                chart=(alt.Chart(alt.Data(values=rows)).mark_bar().encode(
                x=alt.X('grouping:N',sort=ordered,title=mode),y=alt.Y('respondents:Q'),
                color=alt.Color('segment:N',scale=alt.Scale(domain=['Low','Medium','High'],
                                          range=['#2A67E8','#64B5F6','#3F4DBA'])),
                tooltip=tooltips(rows)).properties(height=380))
                alt_chart(chart)
        source_below_chart(sqlname);results(rows,name=sqlname)

elif section=='AI Adoption and Usage':
    st.header('AI Adoption and Usage')
    t8,t9,t10,t11=st.tabs(['Q8 · AI & languages','Q9 · Coding agents','Q10 · Delegation','Q11 · Usage & trust'])
    with t8:
        heading(8)
        n=st.slider('Minimum language users',5,1500,50,key='q8_min')
        rows=fetch('08_ai_by_language.sql',min_users=n)
        metric=st.radio('Percentage displayed',['AI adoption','Unmatched AI-assisted use'],horizontal=True)
        column='pct_with_ai' if metric=='AI adoption' else 'pct_unmatched_ai'

        bar(rows,'language',column,limit=25)
        if rows:
            st.markdown('**Adoption versus mismatch by language**')
            # Both quantitative fields come from the SQL result, not a Python calculation.
            labeled_scatter(rows,'pct_with_ai','pct_unmatched_ai',label='language',size='ai_language_selections',color_title='Mismatch (%)')

        source_below_chart('08_ai_by_language.sql');results(rows,name='08_ai_by_language.sql')
    with t9:
        heading(9)
        n=st.slider('Minimum agent users (strictly greater than)',1,1500,50)
        rows=fetch('09_ai_tools.sql',min_users=n)
        labeled_scatter(rows,'users','avg_trust',label='technology_name',size='users',color_title='Average trust',ymax=4)

        source_below_chart('09_ai_tools.sql');results(rows,name='09_ai_tools.sql')
    with t10:
        heading(10)
        rows=fetch('10_delegated_above_average.sql')
        if rows:
            # Categorical histogram is computed in SQL, not aggregated by Python.
            hist=fetch('10_task_kind_histogram.sql')
            st.markdown('**Distribution of task types delegated (eligible respondents)**')
            bar(hist,'task_kinds','respondents',limit=30)

        source_below_chart('10_delegated_above_average.sql')
        results(rows,max_rows=200,name='10_delegated_above_average.sql')
    with t11:
        heading(11)
        rows=fetch('11_usage_vs_trust.sql')
        # Categorical X axis must follow the ordered usage codes from SQL.
        line(rows,'usage_label','avg_trust',zero=True,ymax=4)

        source_below_chart('11_usage_vs_trust.sql');results(rows,name='11_usage_vs_trust.sql')

elif section=='Technology Landscape':
    st.header('Technology Landscape')
    t12,t13,t14=st.tabs(['Q12 · Databases','Q13 · Languages','Q14 · Country rankings'])
    with t12:
        heading(12)
        n=st.slider('Minimum database users',1,1500,50)
        rows=fetch('12_database_retention.sql',min_users=n)
        labeled_scatter(rows,'users','pct_keep',label='technology_name',size='users',color_title='Retention (%)')

        source_below_chart('12_database_retention.sql');results(rows,name='12_database_retention.sql')
    with t13:
        heading(13)
        histogram_rows=fetch('13_language_count_histogram.sql')
        st.markdown('**Histogram · number of languages per respondent**')
        if histogram_rows:
            chart=(alt.Chart(alt.Data(values=histogram_rows)).mark_bar(color=BLUE).encode(
                x=alt.X('languages:O',title='Number of programming languages',
                        sort=category_sort_order(histogram_rows, 'languages')),
                y=alt.Y('respondents:Q',title='Respondents'),tooltip=tooltips(histogram_rows)).properties(height=375))
            alt_chart(chart)

        rows=fetch('13_multilingual_above_average.sql')
        source_below_chart('13_multilingual_above_average.sql')
        with st.expander('SQL used to calculate the histogram'):
            st.code((QUERIES/'13_language_count_histogram.sql').read_text(encoding='utf-8'),language='sql')
        results(rows,max_rows=200,name='13_multilingual_above_average.sql')
    with t14:
        heading(14)
        top_n=st.slider('Top ranked languages per country',1,15,5)
        rows=fetch('14_language_ranks.sql',top_n=top_n)
        if rows:
            languages=sorted({r['language'] for r in rows})
            selected=st.selectbox('Map a language (countries where it is in the top N)',languages)
            # The geographical subset is selected inside PostgreSQL, not in Python.
            # Ranking is computed across all languages before filtering the map language.
            selected_rows=fetch('map_14_language.sql',top_n=top_n,language=selected)
            map_countries(selected_rows,'country','users',f'Reported users of {selected} by country')

        source_below_chart('14_language_ranks.sql')
        with st.expander('SQL used to prepare the country map'):
            st.code((QUERIES/'map_14_language.sql').read_text(encoding='utf-8-sig'),language='sql')
        results(rows,max_rows=750,name='14_language_ranks.sql')

else:
    st.header('Data Maintenance')
    heading(15)
    st.warning('Demonstration only: SQL deletions are always rolled back, never committed.')
    rid=st.number_input('Respondent ID',min_value=1,value=int(options['example_respondent']),step=1,key='delete_id')
    confirmation=st.checkbox('I understand that the deletion is temporary and will be rolled back')
    if st.button('Execute and roll back',disabled=not confirmation):
        try:
            result=rollback_delete_demo(int(rid))
            st.json(result)
            if result.get('all_records_restored'):st.success('Rollback confirmed: all original records have been restored.')
        except Exception as ex:st.error(f'Demo failed; transaction rolled back: {ex}')

    # Show the actual student-written SQL; never execute it directly from the UI.
    if (QUERIES/'15_data_maintenance.sql').exists():
        source_below_chart('15_data_maintenance.sql',respondent_id=rid)

st.markdown("<div class='page-footer'>PROJECT B &nbsp;·&nbsp; STACK OVERFLOW 2026 &nbsp;/&nbsp; POSTGRESQL + SQL + STREAMLIT</div>",unsafe_allow_html=True)
