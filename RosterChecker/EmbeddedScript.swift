import Foundation
enum EmbeddedScript {
    static let verifyRosterPy = """
#!/usr/bin/env python3
\"\"\"花名册核对脚本
用法:
  完整核对: python3 verify_roster.py <contact_list.pdf> <花名册.xlsx> [--json] [--output 结果.xlsx]
  仅英文名: python3 verify_roster.py <contact_list.pdf> <通讯录-导出.xlsx> --english-only [--json]
\"\"\"
import sys, re, json, pdfplumber, openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

# ── PDF 解析 (共用) ──
def parse_contact_list(pdf_path):
    skip = {'allstaff@290.com.hk','executivecommittee@290.com.hk','staff@fortune3369.com.hk',
            'staff@ffc.com.hk','assetmgmt@290.com.hk','szstaff@290.com.hk',
            'staff@fortune-finance.com.hk','finance@290.com.hk','capops@290.com.hk',
            'comsec@290.com.hk','legal@290.com.hk','compliance@290.com.hk',
            'edo@290.com.hk','ai@290.com.hk'}
    records = {}
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if not text: continue
            for line in text.split('\\n'):
                m = re.search(r'([\\w.+-]+@[\\w.-]+\\.\\w+)', line)
                if not m: continue
                email = m.group(1).lower()
                if email in skip: continue
                prefix = line[:m.start()].strip(); tokens = prefix.split()
                phones, name_tokens = [], []
                for t in tokens:
                    cln = re.sub(r'[^\\d]','',t)
                    if re.match(r'^\\d{7,15}$', cln): phones.append(t)
                    elif t != 'P': name_tokens.append(t)
                dl, mob = '', ''
                if len(phones) >= 2: dl, mob = phones[0], phones[-1]
                elif len(phones) == 1:
                    if '-' in phones[0]: dl = phones[0]
                    else: mob = phones[0]
                # 英文名推导
                ep = email.split('@')[0]; sp = ''
                for nt in name_tokens:
                    if ep.endswith(nt.lower()) and len(nt) > len(sp): sp = nt.lower()
                en = ''
                en_is_pinyin = False
                if sp:
                    en = re.sub(r'[^a-zA-Z]','',ep[:-len(sp)])
                    if en:
                        en = en[0].upper()+en[1:].lower()
                        # 如果英文名部分比姓氏短，大概率是拼音（如 sunqing → en=sun < sp=qing）
                        if len(en) < len(sp):
                            en_is_pinyin = True
                records[email] = {'name':' '.join(name_tokens),'direct_line':dl,'mobile':mob,'english_name':en,'en_is_pinyin':en_is_pinyin}
    return records

def norm_phone(p):
    return re.sub(r'^(852|86)','',p.replace(' ','').replace('-','').replace('+',''))

def phones_match(a,b):
    na,nb=norm_phone(a),norm_phone(b)
    return na==nb or (na and nb and (na.endswith(nb) or nb.endswith(na)))

# ── 模式1: 完整核对 (原版逻辑，保持不变) ──
def parse_roster_full(xlsx_path):
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    if '在职人员' not in wb.sheetnames:
        raise ValueError(\"完整核对需要「在职人员」Sheet，飞书模版请用 --english-only\")
    ws = wb['在职人员']
    hdr = [c.value for c in next(ws.iter_rows(min_row=1,max_row=1))]
    def fc(*ks):
        for k in ks:
            if k in hdr: return hdr.index(k)
        return None
    ni,ei,pi,mi,di,si = fc('姓名'),fc('工作邮箱'),fc('直拨电话/移动电话'),fc('手机号码'),fc('部门'),fc('人员状态')
    en_idx = fc('英文名','别名')
    if None in (ni,ei,pi,mi,di,si):
        raise ValueError(\"花名册缺少必要列\")
    records = {}
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[si] != '在职': continue
        email = (row[ei] or '').strip().lower()
        if not email: continue
        records[email] = {
            'name':(row[ni] or '').strip(),'email':email,
            'direct_line':(row[pi] or '').strip(),
            'mobile':(row[mi] or '').strip(),
            'dept':(row[di] or '').strip(),
            'english_name':(row[en_idx] or '').strip() if en_idx is not None else '',
        }
    return records

def compare_full(roster_data, cl_data):
    errors, only_roster, only_cl = [], [], []
    for email, ex in roster_data.items():
        if email not in cl_data: only_roster.append(ex); continue
        cl = cl_data[email]; has_err = False
        err = {'name':ex['name'],'email':email,'dept':ex['dept'],
               'dl_excel':ex['direct_line'],'dl_cl':'',
               'mob_excel':ex['mobile'],'mob_cl':cl['mobile'],
               'en_excel':ex.get('english_name',''),'en_expected':cl['english_name']}
        if cl['direct_line']:
            err['dl_cl'] = cl['direct_line']
            if not phones_match(ex['direct_line'], cl['direct_line']): has_err = True
        else:
            err['dl_cl'] = cl['mobile']
            if cl['mobile'] and not phones_match(ex['direct_line'], cl['mobile']): has_err = True
        if cl['mobile'] and not phones_match(ex['mobile'], cl['mobile']): has_err = True
        if ex.get('english_name','').strip().lower() != cl['english_name'].lower(): has_err = True
        if has_err: errors.append(err)
    for e in set(cl_data.keys()) - set(roster_data.keys()):
        only_cl.append(cl_data[e])
    return errors, only_roster, only_cl

# ── 模式2: 仅英文名核对 (飞书模版) ──
def parse_roster_english(xlsx_path):
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    ws = wb['Sheet1'] if 'Sheet1' in wb.sheetnames else wb[wb.sheetnames[0]]
    # 找表头行 (\"用户 ID\")
    header_row = None
    for ridx, row in enumerate(ws.iter_rows(max_row=10, values_only=True)):
        vals = [str(c) if c else '' for c in row]
        if '用户 ID' in vals: header_row = ridx; break
    if header_row is None: raise ValueError(\"找不到飞书模版表头\")
    hdr = [str(c) if c else '' for c in next(ws.iter_rows(min_row=header_row+1, max_row=header_row+1, values_only=True))]
    # 飞书列: 姓名(col2) 联系手机(col3) 部门(col4) 工作邮箱(col5) 英文名(col20)
    email_col = hdr.index('工作邮箱') if '工作邮箱' in hdr else None
    en_col = hdr.index('英文名') if '英文名' in hdr else None
    name_col = hdr.index('姓名') if '姓名' in hdr else None
    dept_col = hdr.index('部门') if '部门' in hdr else None
    if email_col is None or en_col is None:
        raise ValueError(\"飞书模版缺少「工作邮箱」或「英文名」列\")
    records = {}
    for row in ws.iter_rows(min_row=header_row+2, values_only=True):
        email = (row[email_col] or '').strip().lower()
        if not email: continue
        name = str(row[name_col] or '').split('|')[0].strip() if name_col else ''
        dept = str(row[dept_col] or '') if dept_col else ''
        records[email] = {
            'name':name,'email':email,'dept':dept,
            'english_name':str(row[en_col] or '').strip(),
            'direct_line':'','mobile':'',
        }
    return records

def compare_english(roster_data, cl_data):
    errors = []
    for email, ex in roster_data.items():
        if email not in cl_data: continue
        cl = cl_data[email]
        # 如果预期英文名是拼音，且 Excel 英文名为空 → 不报错
        if cl.get('en_is_pinyin') and not ex['english_name'].strip():
            continue
        if ex['english_name'].lower() != cl['english_name'].lower():
            errors.append({
                'name':ex['name'],'email':email,'dept':ex['dept'],
                'dl_excel':'','dl_cl':'','mob_excel':'','mob_cl':'',
                'en_excel':ex['english_name'],'en_expected':cl['english_name']
            })
    return errors

# ── 输出 Excel ──
def write_errors_xlsx(errors, output_path):
    if not errors:
        wb=openpyxl.Workbook()
        ws=wb.active; ws.title='信息不一致'
        ws.cell(row=1,column=1,value='没有英文名不一致的项'); wb.save(output_path); return
    wb=openpyxl.Workbook(); ws=wb.active; ws.title='英文名核对'
    hf=PatternFill(start_color='4472C4',end_color='4472C4',fill_type='solid')
    hfw=Font(bold=True,size=11,color='FFFFFF')
    tb=Border(left=Side(style='thin'),right=Side(style='thin'),top=Side(style='thin'),bottom=Side(style='thin'))
    hdrs=['姓名','邮箱','部门','英文名(Excel)','英文名(预期)']
    for c,h in enumerate(hdrs,1):
        cell=ws.cell(row=1,column=c,value=h)
        cell.font=hfw; cell.fill=hf; cell.alignment=Alignment(horizontal='center'); cell.border=tb
    for i,e in enumerate(errors,2):
        for j,k in enumerate(['name','email','dept','en_excel','en_expected']):
            cell=ws.cell(row=i,column=j+1,value=e.get(k,''))
            cell.border=tb; cell.alignment=Alignment(horizontal='center')
    for c in 'ABCDE': ws.column_dimensions[c].width = 22
    ws.column_dimensions['B'].width = 36
    wb.save(output_path)

def write_full_xlsx(errors, only_roster, only_cl, output_path):
    wb=openpyxl.Workbook()
    hf=PatternFill(start_color='4472C4',end_color='4472C4',fill_type='solid')
    hfw=Font(bold=True,size=11,color='FFFFFF')
    tb=Border(left=Side(style='thin'),right=Side(style='thin'),top=Side(style='thin'),bottom=Side(style='thin'))
    def sh(ws, hdrs):
        for c,h in enumerate(hdrs,1):
            cell=ws.cell(row=1,column=c,value=h); cell.font=hfw; cell.fill=hf
            cell.alignment=Alignment(horizontal='center'); cell.border=tb
    def sd(ws,mr,mc):
        for r in range(2,mr+1):
            for c in range(1,mc+1): cell=ws.cell(row=r,column=c); cell.border=tb; cell.alignment=Alignment(horizontal='center')
    ws1=wb.active; ws1.title='信息不一致'
    h1=['姓名','邮箱','部门','直拨电话(花名册)','直拨电话(CL)','手机(花名册)','手机(CL)','英文名(花名册)','英文名(预期)']
    sh(ws1,h1)
    for i,e in enumerate(errors,2):
        for j,k in enumerate(['name','email','dept','dl_excel','dl_cl','mob_excel','mob_cl','en_excel','en_expected']):
            ws1.cell(row=i,column=j+1,value=e.get(k,''))
    sd(ws1,len(errors)+1,len(h1))
    ws2=wb.create_sheet('花名册独有(CL无)')
    sh(ws2,['姓名','邮箱','部门','直拨电话','手机号码'])
    for i,r in enumerate(only_roster,2):
        for j,k in enumerate(['name','email','dept','direct_line','mobile']):
            ws2.cell(row=i,column=j+1,value=r.get(k,''))
    sd(ws2,len(only_roster)+1,5)
    ws3=wb.create_sheet('ContactList独有(花名册无)')
    sh(ws3,['姓名(英文)','邮箱','直拨电话(CL)','手机(CL)'])
    for i,r in enumerate(only_cl,2):
        for j,k in enumerate(['name','email','direct_line','mobile']):
            ws3.cell(row=i,column=j+1,value=r.get(k,''))
    sd(ws3,len(only_cl)+1,4)
    for ws,cs in [(ws1,'ABCDEFGHI'),(ws2,'ABCDE'),(ws3,'ABCD')]:
        for c in cs: ws.column_dimensions[c].width=22
    ws1.column_dimensions['B'].width=36; ws3.column_dimensions['B'].width=36
    wb.save(output_path)

# ── 主入口 ──
if __name__ == '__main__':
    json_mode = '--json' in sys.argv
    english_mode = '--english-only' in sys.argv
    raw = [a for a in sys.argv[1:] if a not in ('--json','--english-only')]
    output_path = None
    remaining = []; i = 0
    while i < len(raw):
        if raw[i] == '--output' and i+1 < len(raw): output_path = raw[i+1]; i += 2
        else: remaining.append(raw[i]); i += 1
    if len(remaining) < 2:
        print(\"用法: python3 verify_roster.py <contact_list.pdf> <花名册.xlsx> [--english-only] [--json] [--output 结果.xlsx]\")
        sys.exit(1)

    cl_data = parse_contact_list(remaining[0])

    if english_mode:
        roster_data = parse_roster_english(remaining[1])
        errors = compare_english(roster_data, cl_data)
        if json_mode:
            print(json.dumps({
                'summary':{'cl_count':len(cl_data),'roster_count':len(roster_data),'error_count':len(errors),'only_roster_count':0,'only_cl_count':0},
                'errors':errors,'only_roster':[],'only_cl':[]
            }, ensure_ascii=False, indent=2))
        else:
            write_errors_xlsx(errors, output_path or '英文名核对结果.xlsx')
            print(f\"英文名不一致: {len(errors)} 人\")
    else:
        roster_data = parse_roster_full(remaining[1])
        errors, only_roster, only_cl = compare_full(roster_data, cl_data)
        if json_mode:
            print(json.dumps({
                'summary':{'cl_count':len(cl_data),'roster_count':len(roster_data),
                           'error_count':len(errors),'only_roster_count':len(only_roster),'only_cl_count':len(only_cl)},
                'errors':errors,
                'only_roster':[{'name':r['name'],'email':r.get('email',''),'dept':r['dept'],'direct_line':r['direct_line'],'mobile':r['mobile']} for r in only_roster],
                'only_cl':[{'name':r['name'],'email':r.get('email',''),'direct_line':r['direct_line'],'mobile':r['mobile']} for r in only_cl]
            }, ensure_ascii=False, indent=2))
        else:
            write_full_xlsx(errors, only_roster, only_cl, output_path or '核对结果.xlsx')
            print(f\"信息不一致:{len(errors)} 花名册独有:{len(only_roster)} CL独有:{len(only_cl)}\")

"""
}
