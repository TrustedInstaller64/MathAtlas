import Foundation

struct Problem: Identifiable, Codable, Equatable {
    var id: String
    var contentType: String        // "latex", "text", or "image"
    var latex: String              // LaTeX source or plain text (based on contentType)
    var tags: [String]
    var category: String
    var source: String
    var note: String
    var solution: String
    var solutionContentType: String  // "latex", "text", or "image"
    var solutionImageNames: [String]
    var imageNames: [String]
    var createdAt: TimeInterval
    var updatedAt: TimeInterval

    static let categories = ["填空题", "选择题", "解答题", "未分类"]
    static let contentTypes = ["latex", "text", "image"]
    static let contentTypeLabels = ["LaTeX 公式", "纯文本", "图片"]

    static let empty: Self = Problem(
        id: "", contentType: "latex", latex: "", tags: [], category: "填空题",
        source: "", note: "", solution: "", solutionContentType: "latex",
        solutionImageNames: [], imageNames: [],
        createdAt: 0, updatedAt: 0
    )
}

// MARK: - Seed Data (2026 Shanghai Spring Exam)

extension Problem {
    static func seedProblems(for level: AppLevel = AppLevel.high) -> [Problem] {
        if level.id == "high" { return highSchoolSeeds }
        if level.id == "middle" { return middleSchoolSeeds }
        return []
    }

    // MARK: - High School Seeds (2026 Shanghai Spring Exam)

    static let highSchoolSeeds: [Problem] = {
        let now = Date().timeIntervalSince1970
        return [
            Problem(
                id: "seed-1",
                contentType: "latex",
                latex: "已知集合 \\( A = \\{2,3\\} \\)，\\( B = \\{2,4,m\\} \\)，若 \\( A \\subseteq B \\)，则 \\( m \\) 的值为\\_\\_\\_\\_\\_\\_.",
                tags: ["集合", "子集"],
                category: "填空题",
                source: "2026春考",
                note: "",
                solution: "由 \\(A \\subseteq B\\) 知 \\(m\\) 必须等于 \\(3\\)（集合元素互异性）。\n\\(B = \\{2,4,m\\}\\)，若 \\(A \\subseteq B\\)，则 \\(3 \\in B\\)，故 \\(m = 3\\)。",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "seed-2",
                contentType: "latex",
                latex: "不等式 \\(\\frac{x+2}{x-3} < 0\\) 的解集为\\_\\_\\_\\_\\_\\_.",
                tags: ["不等式", "分式不等式"],
                category: "填空题",
                source: "2026春考",
                note: "",
                solution: "",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "seed-3",
                contentType: "latex",
                latex: "二项式 \\(\\left( \\frac{1}{x} + 3x^2 \\right)^6\\) 的展开式中，\\(\\frac{1}{x^3}\\) 的系数为\\_\\_\\_\\_\\_\\_.",
                tags: ["二项式定理", "展开式系数"],
                category: "填空题",
                source: "2026春考",
                note: "",
                solution: "",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "seed-4",
                contentType: "latex",
                latex: "已知椭圆 \\(\\Gamma_1: \\frac{x^2}{a^2} + y^2 = 1(a > 1)\\) 与 \\(\\Gamma_2: \\frac{y^2}{b^2} + \\frac{x^2}{b^2} = 1(b > 0)\\) 交于 \\( A, B, C, D \\) 四点，若这两个椭圆 \\(\\Gamma_1, \\Gamma_2\\) 的焦点与点 \\( A, B, C, D \\) 均位于同一个圆上，则 \\( b^2 = \\) \\_\\_\\_\\_\\_\\_.",
                tags: ["椭圆", "解析几何", "圆"],
                category: "填空题",
                source: "2026春考",
                note: "压轴填空",
                solution: "",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "seed-5",
                contentType: "latex",
                latex: "下列数列中，即是等差数列，又是等比数列的是（\\quad\\quad）.\n\\begin{enumerate}[label=\\Alph*.]\n    \\item \\(1, -1, 1, -1\\)\n    \\item \\(1, 2, 3, 4\\)\n    \\item \\(5, 5, 5, 5\\)\n    \\item \\(2, 3, 5, 7\\)\n\\end{enumerate}",
                tags: ["数列", "等差数列", "等比数列"],
                category: "选择题",
                source: "2026春考",
                note: "",
                solution: "",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "seed-6",
                contentType: "latex",
                latex: "（第1小题满分4分，第2小题满分4分，第3小题满分6分）\n\n某市民夜校开展了游泳、绘画、摄影、编程等活动，各项目参加人数如下表所示：\n\\begin{center}\n\\begin{tabular}{|c|c|c|c|c|c|c|c|}\n\\hline\n年龄 & 剪纸 & 游泳 & 绘画 & 摄影 & 声乐 & 编程 & 合计 \\\\\n\\hline\n[25,35) & 8 & 6 & 6 & 8 & 7 & 10 & 45 \\\\\n\\hline\n[35,45) & 7 & 10 & 7 & 10 & 14 & 7 & 55 \\\\\n\\hline\n[45,55) & 9 & 8 & 9 & 6 & 16 & 2 & 50 \\\\\n\\hline\n合计 & 24 & 24 & 22 & 24 & 37 & 19 & 150 \\\\\n\\hline\n\\end{tabular}\n\\end{center}\n\\begin{enumerate}\n    \\item 为调查市民参与夜校活动的情况，需采用按年龄段分组随机抽样的方法抽取30人，求抽到的人中，年龄小于35岁且不小于25岁的人数；\n    \\item 试估计参加夜校市民的平均年龄.（精确到0.1）\n    \\item 从该市参加夜校活动的150名市民中随机抽取一人，设事件 \\( A \\) 为\u{201c}抽到的人年龄小于45岁且不小于35岁\u{201d}，事件 \\( B \\) 为\u{201c}抽到的人选择摄影项目\u{201d}，试判断事件 \\( A \\) 与事件 \\( B \\) 是否相互独立，并说明理由.\n\\end{enumerate}",
                tags: ["概率统计", "抽样", "独立性"],
                category: "解答题",
                source: "2026春考",
                note: "含表格",
                solution: "",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "seed-7",
                contentType: "latex",
                latex: "对于定义在 \\( {R} \\) 上的函数 \\( y = f(x) \\)，若任取 \\( |x_1| < |x_2| \\)，总有 \\( f(x_1) < f(x_2) \\)，则称函数 \\( y = f(x) \\) 具有\u{201c}性质 P\u{201d}.\n\\begin{enumerate}\n    \\item 判断函数 \\( f(x) = e^x \\) 是否具有\u{201c}性质 P\u{201d}；\n    \\item 已知函数 \\( f(x) = \\begin{cases} ax, & x \\leq 0 \\\\ x + b, & x > 0 \\end{cases} \\) 具有\u{201c}性质 P\u{201d}，求出所有符合条件的 \\( a, b \\) 的值；\n    \\item 已知函数 \\( f(x) \\) 在 \\( R \\) 上的值域为 \\( [0, 1] \\)，且在区间 \\( [0, +\\infty) \\) 上是严格增函数，证明：\u{201c}\\( y = f(x) \\) 是偶函数\u{201d}的充分必要条件是\u{201c}\\( y = f(x) \\) 具有\u{2018}性质 P\u{2019}\u{201d}.\n\\end{enumerate}",
                tags: ["函数", "抽象函数", "奇偶性", "分段函数"],
                category: "解答题",
                source: "2026春考",
                note: "压轴题，含分段函数",
                solution: "",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
        ]
    }()

    // MARK: - Middle School Seeds

    static let middleSchoolSeeds: [Problem] = {
        let now = Date().timeIntervalSince1970
        return [
            Problem(
                id: "ms-seed-1",
                contentType: "latex",
                latex: "计算：\\( (-3)^2 + \\sqrt{16} - \\frac{1}{2} \\times 4 = \\) \\_\\_\\_\\_\\_\\_.",
                tags: ["有理数运算", "平方根"],
                category: "填空题",
                source: "2026中考",
                note: "",
                solution: "\\( (-3)^2 = 9 \\)，\\( \\sqrt{16} = 4 \\)，\\( \\frac{1}{2} \\times 4 = 2 \\)，\\( 9 + 4 - 2 = 11 \\)",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "ms-seed-2",
                contentType: "latex",
                latex: "一元二次方程 \\( x^2 - 5x + 6 = 0 \\) 的解为 \\( x_1 = \\) \\_\\_\\_\\_\\_\\_，\\( x_2 = \\) \\_\\_\\_\\_\\_\\_.",
                tags: ["一元二次方程", "因式分解"],
                category: "填空题",
                source: "2026中考",
                note: "",
                solution: "\\( x^2 - 5x + 6 = (x-2)(x-3) = 0 \\)，故 \\( x_1 = 2, x_2 = 3 \\)",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "ms-seed-3",
                contentType: "latex",
                latex: "已知一次函数 \\( y = kx + b \\) 的图像经过点 \\( A(1,3) \\) 和 \\( B(-2, -3) \\)，则 \\( k = \\) \\_\\_\\_\\_\\_\\_，\\( b = \\) \\_\\_\\_\\_\\_\\_.",
                tags: ["一次函数", "待定系数法"],
                category: "填空题",
                source: "2026中考",
                note: "",
                solution: "代入 \\( A(1,3) \\)：\\( k + b = 3 \\)；代入 \\( B(-2,-3) \\)：\\( -2k + b = -3 \\)。两式相减得 \\( 3k = 6 \\)，\\( k = 2 \\)，\\( b = 1 \\)",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "ms-seed-4",
                contentType: "latex",
                latex: "下列图形中，既是轴对称图形又是中心对称图形的是（\\quad\\quad）.\n\\begin{enumerate}[label=\\Alph*.]\n    \\item 等腰三角形\n    \\item 平行四边形\n    \\item 矩形\n    \\item 正五边形\n\\end{enumerate}",
                tags: ["对称性", "几何图形"],
                category: "选择题",
                source: "2026中考",
                note: "",
                solution: "矩形既是轴对称（有 2 条对称轴）又是中心对称（对角线交点为中心），选 C",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "ms-seed-5",
                contentType: "latex",
                latex: "如图，在 \\( \\triangle ABC \\) 中，\\( \\angle C = 90^\\circ \\)，\\( AC = 6 \\)，\\( BC = 8 \\)，则 \\( \\sin A = \\) \\_\\_\\_\\_\\_\\_.",
                tags: ["锐角三角函数", "勾股定理"],
                category: "填空题",
                source: "2026中考",
                note: "",
                solution: "由勾股定理 \\( AB = \\sqrt{6^2 + 8^2} = 10 \\)，\\( \\sin A = \\frac{BC}{AB} = \\frac{8}{10} = \\frac{4}{5} \\)",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "ms-seed-6",
                contentType: "latex",
                latex: "（本题满分 10 分）\n\n某校为了了解九年级学生的体育测试情况，随机抽取了部分学生的体育成绩进行统计，结果如下：\n\\begin{center}\n\\begin{tabular}{|c|c|c|c|c|c|}\n\\hline\n成绩（分） & 20-29 & 30-39 & 40-49 & 50-59 & 60 \\\\\n\\hline\n人数 & 2 & 5 & 8 & 12 & 3 \\\\\n\\hline\n\\end{tabular}\n\\end{center}\n\\begin{enumerate}\n    \\item 求被抽取的学生人数；\n    \\item 求这组数据的众数和中位数；\n    \\item 若该校九年级共有 600 名学生，试估计体育成绩在 50 分及以上的人数.\n\\end{enumerate}",
                tags: ["统计", "抽样估计", "众数中位数"],
                category: "解答题",
                source: "2026中考",
                note: "含表格",
                solution: "（1）总人数 = 2+5+8+12+3 = 30 人\n（2）众数：50-59 分段（12 人最多）；中位数在 40-49 分段\n（3）50 分及以上：(12+3)/30 × 600 = 300 人",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
            Problem(
                id: "ms-seed-7",
                contentType: "latex",
                latex: "已知抛物线 \\( y = x^2 - 2mx + m^2 - 1 \\) 与 \\( x \\) 轴交于 \\( A, B \\) 两点（\\( A \\) 在 \\( B \\) 左侧），与 \\( y \\) 轴交于点 \\( C \\).\n\\begin{enumerate}\n    \\item 用含 \\( m \\) 的代数式表示 \\( AB \\) 的长度；\n    \\item 若 \\( \\triangle ABC \\) 的面积为 3，求 \\( m \\) 的值.\n\\end{enumerate}",
                tags: ["二次函数", "抛物线", "三角形面积"],
                category: "解答题",
                source: "2026中考",
                note: "",
                solution: "（1）\\( y = (x-m)^2 - 1 \\)，顶点 \\( (m,-1) \\)，令 \\( y=0 \\) 得 \\( x=m\\pm 1 \\)，\\( AB = 2 \\)\n（2）\\( C(0, m^2-1) \\)，\\( S = \\frac{1}{2} \\times 2 \\times |m^2-1| = |m^2-1| = 3 \\)，\\( m = \\pm 2 \\)",
                solutionContentType: "latex",
                solutionImageNames: [],
                imageNames: [],
                createdAt: now,
                updatedAt: now
            ),
        ]
    }()
}
