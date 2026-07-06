import Foundation
enum EmbeddedScript {
    static let verifyRosterPy = """
#!/usr/bin/env python3
\"\"\"花名册核对脚本 — 兼容原始花名册 和 飞书导出模版\"\"\"

import sys, os, re, json
import pdfplumber
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

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
                prefix = line[:m.start()].strip()
                tokens = prefix.split()
                phones, name_tokens = [], []
                for t in tokens:
                    clean = t.replace(' ','').replace('-','').replace('+','').replace('(','').replace(')','')
                    if re.match(r'^\\d{7,15}$', clean): phones.append(t)
                    elif t != 'P': name_tokens.append(t)
                dl, mob = '', ''
                if len(phones) >= 2: dl, mob = phones[0], phones[-1]
                elif len(phones) == 1:
                    if '-' in phones[0]: dl = phones[0]
                    else: mob = phones[0]
                # 英文名推导
                email_prefix = email.split('@')[0]
                surname_pinyin = ''
                for nt in name_tokens:
                    if email_prefix.endswith(nt.lower()) and len(nt) > len(surname_pinyin):
                        surname_pinyin = nt.lower()
                english_name = ''
                if surname_pinyin:
                    en = re.sub(r'[^a-zA-Z]', '', email_prefix[:-len(surname_pinyin)])
                    if en: english_name = en[0].upper() + en[1:].lower()
                records[email] = {
                    'name': ' '.join(name_tokens), 'direct_line': dl, 'mobile': mob,
                    'english_name': english_name,
                }
    return records

def parse_roster(xlsx_path):
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)

    # 选择 Sheet：先试\"在职人员\"，再试\"Sheet1\"，否则用第一个
    sheet_name = None
    for sn in ['在职人员', 'Sheet1', wb.sheetnames[0]]:
        if sn in wb.sheetnames: sheet_name = sn; break
    ws = wb[sheet_name]

    # 找到表头行：飞书模板表头在“用户 ID”那行，原始花名册在“姓名”那行
    header_row = None
    for row_idx, row in enumerate(ws.iter_rows(max_row=min(ws.max_row, 10), values_only=True)):
        vals = [str(c) if c else '' for c in row]
        if '用户 ID' in vals or '姓名' in vals:
            header_row = row_idx
            break

    if header_row is None:
        raise ValueError(\"找不到表头行\")
    header = [str(c) if c else '' for c in ws[header_row + 1]]

    def fc(*keys):
        for k in keys:
            if k in header: return header.index(k)
        return None

    # 列名映射（兼容两种格式）
    name_idx = fc('姓名')
    email_idx = fc('工作邮箱')
    phone_idx = fc('直拨电话/移动电话')
    mobile_idx = fc('手机号码', '联系手机')
    dept_idx = fc('部门')
    en_idx = fc('英文名', '别名')
    status_idx = fc('人员状态', '账号状态')

    if None in (name_idx, email_idx, phone_idx, mobile_idx, dept_idx):
        missing = []
        for k, v in {'姓名':name_idx,'工作邮箱':email_idx,'直拨电话/移动电话':phone_idx,'手机号码/联系手机':mobile_idx,'部门':dept_idx}.items():
            if v is None: missing.append(k)
        raise ValueError(f\"缺少必要列: {missing}\")

    records = {}
    for row in ws.iter_rows(min_row=header_row + 2, values_only=True):
        email = (row[email_idx] or '').strip()
        if not email: continue
        # 过滤状态：原始花名册 \"在职\"，飞书模板 \"正常\"
        if status_idx is not None:
            status = str(row[status_idx] or '').strip()
            if status and status not in ('在职', '正常'): continue

        # 姓名：飞书模板格式 \"张三|CN-张三|EN-ZhangSan\"，只取第一个部分
        name = str(row[name_idx] or '').split('|')[0].strip()
        dept = str(row[dept_idx] or '').split('/')[-1].strip()  # 飞书模板取最后一级

        en_name = ''
        if en_idx is not None:
            en_name = str(row[en_idx] or '').strip()

        records[email.lower()] = {
            'name': name, 'email': email.lower(),
            'direct_line': str(row[phone_idx] or '').strip(),
            'mobile': str(row[mobile_idx] or '').strip(),
            'dept': dept, 'english_name': en_name,
        }
    return records

def norm_phone(p):
    p = p.replace(' ','').replace('-','').replace('+','').replace('(','').replace(')','')
    return re.sub(r'^(852|86)', '', p)

def phones_match(a, b):
    na, nb = norm_phone(a), norm_phone(b)
    if na == nb: return True
    if na and nb and (na.endswith(nb) or nb.endswith(na)): return True
    return False

def compare(roster_data, cl_data):
    errors, only_roster, only_cl = [], [], []
    for email, ex in roster_data.items():
        if email not in cl_data:
            only_roster.append(ex); continue
        cl = cl_data[email]
        has_err = False
        err = {
            'name':ex['name'],'email':email,'dept':ex['dept'],
            'dl_excel':ex['direct_line'],'dl_cl':'',
            'mob_excel':ex['mobile'],'mob_cl':cl['mobile'],
            'en_excel':ex.get('english_name',''),'en_expected':cl['english_name'],
        }
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

def write_xlsx(errors, only_roster, only_cl, output_path):
    wb = openpyxl.Workbook()
    hf = PatternFill(start_color='4472C4', end_color='4472C4', fill_type='solid')
    hfw = Font(bold=True, size=11, color='FFFFFF')
    tb = Border(left=Side(style='thin'),right=Side(style='thin'),top=Side(style='thin'),bottom=Side(style='thin'))
    def sh(ws, hdrs):
        for c, h in enumerate(hdrs, 1):
            cell = ws.cell(row=1, column=c, value=h)
            cell.font = hfw; cell.fill = hf
            cell.alignment = Alignment(horizontal='center'); cell.border = tb
    def sd(ws, mr, mc):
        for r in range(2, mr+1):
            for c in range(1, mc+1):
                cell = ws.cell(row=r, column=c)
                cell.border = tb; cell.alignment = Alignment(horizontal='center')
    ws1 = wb.active; ws1.title = '信息不一致'
    h1 = ['姓名','邮箱','部门','直拨电话(花名册)','直拨电话(CL)','手机(花名册)','手机(CL)','英文名(花名册)','英文名(预期)']
    sh(ws1, h1)
    for i, e in enumerate(errors, 2):
        for j, k in enumerate(['name','email','dept','dl_excel','dl_cl','mob_excel','mob_cl','en_excel','en_expected']):
            ws1.cell(row=i, column=j+1, value=e.get(k,''))
    sd(ws1, len(errors)+1, len(h1))
    ws2 = wb.create_sheet('花名册独有(CL无)')
    h2 = ['姓名','邮箱','部门','直拨电话','手机号码']
    sh(ws2, h2)
    for i, r in enumerate(only_roster, 2):
        for j, k in enumerate(['name','email','dept','direct_line','mobile']):
            ws2.cell(row=i, column=j+1, value=r.get(k,''))
    sd(ws2, len(only_roster)+1, len(h2))
    ws3 = wb.create_sheet('ContactList独有(花名册无)')
    h3 = ['姓名(英文)','邮箱','直拨电话(CL)','手机(CL)']
    sh(ws3, h3)
    for i, r in enumerate(only_cl, 2):
        for j, k in enumerate(['name','email','direct_line','mobile']):
            ws3.cell(row=i, column=j+1, value=r.get(k,''))
    sd(ws3, len(only_cl)+1, len(h3))
    for ws, cols in [(ws1,'ABCDEFGHI'),(ws2,'ABCDE'),(ws3,'ABCD')]:
        for c in cols: ws.column_dimensions[c].width = 22
    ws1.column_dimensions['B'].width = 36; ws3.column_dimensions['B'].width = 36
    wb.save(output_path)

if __name__ == '__main__':
    json_mode = '--json' in sys.argv
    args = [a for a in sys.argv[1:] if a != '--json']
    output_path = None
    remaining = []; i = 0
    while i < len(args):
        if args[i] == '--output' and i+1 < len(args):
            output_path = args[i+1]; i += 2
        else:
            remaining.append(args[i]); i += 1
    if len(remaining) < 2:
        print(\"用法: python3 verify_roster.py <contact_list.pdf> <花名册.xlsx> [--json] [--output 结果.xlsx]\")
        sys.exit(1)
    cl_data = parse_contact_list(remaining[0])
    roster_data = parse_roster(remaining[1])
    errors, only_roster, only_cl = compare(roster_data, cl_data)
    if json_mode:
        print(json.dumps({
            'summary': {'cl_count':len(cl_data),'roster_count':len(roster_data),
                        'error_count':len(errors),'only_roster_count':len(only_roster),'only_cl_count':len(only_cl)},
            'errors':errors,
            'only_roster':[{'name':r['name'],'email':r.get('email',''),'dept':r['dept'],'direct_line':r['direct_line'],'mobile':r['mobile']} for r in only_roster],
            'only_cl':[{'name':r['name'],'email':r.get('email',''),'direct_line':r['direct_line'],'mobile':r['mobile']} for r in only_cl]
        }, ensure_ascii=False, indent=2))
    else:
        write_xlsx(errors, only_roster, only_cl, output_path or '核对结果.xlsx')
        print(f\"信息不一致:{len(errors)} 花名册独有:{len(only_roster)} CL独有:{len(only_cl)}\")

"""
}
