/**
 * 饮食记录数据库帮助类
 * 使用 relationalStore 存储每日饮食记录，模式与 RecipeDBManager 保持一致：
 * 静态 singleton + Promise 防并发初始化。
 */
import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'

const DB_NAME = 'diet.db'
const TABLE = 'diet_records'

const SQL_CREATE_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE} (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    date        TEXT    NOT NULL,
    meal_type   TEXT    DEFAULT '加餐',
    food_name   TEXT    NOT NULL,
    quantity    REAL    NOT NULL DEFAULT 1.0,
    unit        TEXT    DEFAULT '份',
    calories    REAL    NOT NULL DEFAULT 0,
    protein     REAL    DEFAULT 0,
    fat         REAL    DEFAULT 0,
    carbs       REAL    DEFAULT 0,
    image_uri   TEXT    DEFAULT '',
    timestamp   INTEGER DEFAULT 0
  )
`

/** 与数据库行对应的饮食记录结构 */
export interface DietRecord {
  id?: number
  /** 日期字符串，格式 'YYYY-MM-DD' */
  date: string
  mealType: string
  foodName: string
  quantity: number
  unit: string
  /** 该条记录的总热量（千卡，已含份量换算） */
  calories: number
  protein: number
  fat: number
  carbs: number
  imageUri: string
  timestamp: number
}

/** 今日摄入汇总 */
export interface DailyTotal {
  totalCalories: number
  totalProtein: number
  totalFat: number
  totalCarbs: number
  recordCount: number
}

export class DietDatabaseHelper {
  private static instance: DietDatabaseHelper | null = null
  private store: relationalStore.RdbStore | null = null
  private opening: Promise<relationalStore.RdbStore> | null = null

  static getInstance(): DietDatabaseHelper {
    if (DietDatabaseHelper.instance === null) {
      DietDatabaseHelper.instance = new DietDatabaseHelper()
    }
    return DietDatabaseHelper.instance
  }

  // ── 初始化 ──────────────────────────────────────────────────────────

  /** 确保数据库已打开并建表，页面 aboutToAppear 时调用 */
  async ensureReady(context: common.Context): Promise<void> {
    await this.getStore(context)
  }

  private async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (this.store !== null) return this.store
    if (this.opening !== null) return await this.opening

    this.opening = relationalStore.getRdbStore(context, {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
    }).then(async (s: relationalStore.RdbStore) => {
      await s.executeSql(SQL_CREATE_TABLE)
      this.store = s
      this.opening = null
      return s
    }).catch((e: Error) => {
      this.opening = null
      throw e
    })

    return await this.opening
  }

  // ── 写操作 ──────────────────────────────────────────────────────────

  /** 插入一条饮食记录，返回新行的 rowId */
  async insertRecord(context: common.Context, record: DietRecord): Promise<number> {
    const s = await this.getStore(context)
    const bucket: relationalStore.ValuesBucket = {
      date:       record.date,
      meal_type:  record.mealType,
      food_name:  record.foodName,
      quantity:   record.quantity,
      unit:       record.unit,
      calories:   record.calories,
      protein:    record.protein,
      fat:        record.fat,
      carbs:      record.carbs,
      image_uri:  record.imageUri,
      timestamp:  record.timestamp,
    }
    return await s.insert(TABLE, bucket)
  }

  /** 删除指定 id 的记录 */
  async deleteRecord(context: common.Context, id: number): Promise<void> {
    const s = await this.getStore(context)
    const predicates = new relationalStore.RdbPredicates(TABLE)
    predicates.equalTo('id', id)
    await s.delete(predicates)
  }

  // ── 查询操作 ─────────────────────────────────────────────────────────

  /**
   * 查询指定日期的所有记录，按 timestamp 倒序排列。
   * @param dateStr 格式 'YYYY-MM-DD'
   */
  async queryByDate(context: common.Context, dateStr: string): Promise<DietRecord[]> {
    const s = await this.getStore(context)
    const predicates = new relationalStore.RdbPredicates(TABLE)
    predicates.equalTo('date', dateStr)
    predicates.orderByDesc('timestamp')

    const rs = await s.query(predicates, [
      'id', 'date', 'meal_type', 'food_name', 'quantity', 'unit',
      'calories', 'protein', 'fat', 'carbs', 'image_uri', 'timestamp',
    ])
    const records: DietRecord[] = []
    try {
      while (rs.goToNextRow()) {
        records.push({
          id:        rs.getLong(rs.getColumnIndex('id')),
          date:      rs.getString(rs.getColumnIndex('date')),
          mealType:  rs.getString(rs.getColumnIndex('meal_type')),
          foodName:  rs.getString(rs.getColumnIndex('food_name')),
          quantity:  rs.getDouble(rs.getColumnIndex('quantity')),
          unit:      rs.getString(rs.getColumnIndex('unit')),
          calories:  rs.getDouble(rs.getColumnIndex('calories')),
          protein:   rs.getDouble(rs.getColumnIndex('protein')),
          fat:       rs.getDouble(rs.getColumnIndex('fat')),
          carbs:     rs.getDouble(rs.getColumnIndex('carbs')),
          imageUri:  rs.getString(rs.getColumnIndex('image_uri')),
          timestamp: rs.getLong(rs.getColumnIndex('timestamp')),
        })
      }
    } finally {
      rs.close()
    }
    return records
  }

  /** 查询今日（本设备本地日期）所有记录 */
  async queryTodayRecords(context: common.Context): Promise<DietRecord[]> {
    return this.queryByDate(context, DietDatabaseHelper.todayDateStr())
  }

  /** 查询今日摄入汇总（热量+三大营养素合计） */
  async queryTodayTotal(context: common.Context): Promise<DailyTotal> {
    const s = await this.getStore(context)
    const dateStr = DietDatabaseHelper.todayDateStr()
    const rs = await s.querySql(
      `SELECT SUM(calories) AS cal, SUM(protein) AS pro,
              SUM(fat) AS fat, SUM(carbs) AS carbs,
              COUNT(*) AS cnt
       FROM ${TABLE} WHERE date = ?`,
      [dateStr],
    )
    let result: DailyTotal = {
      totalCalories: 0, totalProtein: 0,
      totalFat: 0, totalCarbs: 0, recordCount: 0,
    }
    try {
      if (rs.goToFirstRow()) {
        result = {
          totalCalories: rs.getDouble(rs.getColumnIndex('cal')),
          totalProtein:  rs.getDouble(rs.getColumnIndex('pro')),
          totalFat:      rs.getDouble(rs.getColumnIndex('fat')),
          totalCarbs:    rs.getDouble(rs.getColumnIndex('carbs')),
          recordCount:   rs.getLong(rs.getColumnIndex('cnt')),
        }
      }
    } finally {
      rs.close()
    }
    return result
  }

  // ── 工具 ─────────────────────────────────────────────────────────────

  /** 返回今日日期字符串，格式 'YYYY-MM-DD' */
  static todayDateStr(): string {
    const now = new Date()
    const y = now.getFullYear()
    const m = String(now.getMonth() + 1).padStart(2, '0')
    const d = String(now.getDate()).padStart(2, '0')
    return `${y}-${m}-${d}`
  }
}
