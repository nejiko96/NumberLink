#include <stdio.h>
#include <memory.h>
#include <errno.h>
#include "Utils.h"

//#define DEBUG 1
#define BREAK 1000

#define MIN_SIZE 1
#define MAX_SIZE 15
#define MAX_DEFS 15
#define MIN_POINTS 2
#define MAX_POINTS 29
#define MAX_PARTS 63

#define STAT_LEN 3
#define LINK_NAME_LEN 2

#define NEIGHBOR_CNT 4
#define AROUND_CNT 8
#define SPLIT_PAT_CNT 256

#define RET_OK 0
#define RET_NG -1

#define FLG_ON 1
#define FLG_OFF 0

#define START_MARK "S"
#define MID_MARK "M"
#define END_MARK "E"
#define CLOSE_MARK "*"
#define FILLER " . "
#define FD1_MARK " o "

#define DIR_RIGHT 0
#define DIR_DOWN 1
#define DIR_LEFT 2
#define DIR_UP 3

#define H_WALL "---"
#define DOWN_MARK " v "
#define UP_MARK " ^ "

#define V_WALL "|"
#define RIGHT_MARK ">"
#define LEFT_MARK "<"

#define HAS_LINK(link)		(*(link->pcLinkName) != '\0')
#define HAS_POINT(p)		(p->cRow >= 0)
#define HAS_NEIGHBOR(nbor)	(nbor->pstDir != NULL)

#ifdef DEBUG
#define DEBUG_PRINTF(fmt, ...) \
  /* printf("%s:%d：%s\n", __FILE__, __LINE__, __func__); */ \
  printf(fmt, ##__VA_ARGS__)
#define DEBUG_PRINT_GRID(status) print_grid(status)
#define DEBUG_PRINT_LINK(link) print_link(link)
#define DEBUG_PRINT_LINKS(links) print_links(links)
#define DEBUG_PRINT_EXIT(exit) print_exit(exit)
#define DEBUG_DUMP(ptr, size) HexDumpToStdout((char *) ptr, size)
#else
#define DEBUG_PRINTF(fmt, ...)
#define DEBUG_PRINT_GRID(status)
#define DEBUG_PRINT_LINK(link)
#define DEBUG_PRINT_LINKS(links)
#define DEBUG_PRINT_EXIT(exit)
#define DEBUG_DUMP(ptr, size)
#endif

#define LINE_BUF_LEN 255

#define _consume_char(ptr) (*(ptr++) = '\0')
#define _consume_space(ptr) while (isspace(*ptr)) { _consume_char(ptr); }
#define _consume_delim(ptr) _consume_char(ptr); _consume_space(ptr)
#define _get_token(ptr, chr) while (*ptr != '\0' && !isspace(*ptr) && *ptr != chr) { ptr++; } _consume_space(ptr)
#define _get_number(ptr) while (*ptr != '\0' && isdigit(*ptr)) { ptr++; } _consume_space(ptr)
#define _parse_error(fmt, ...) printf("%s(%d) : " fmt, pcFileName, iLineCnt, ##__VA_ARGS__)


typedef struct __POINT {
	char cRow;
	char cCol;
} POINT, *pPOINT;

typedef struct __LINK_DEF {
	char pcLinkName[STAT_LEN + 1];
	POINT pstPoints[MAX_POINTS + 1];
} LINK_DEF, *pLINK_DEF;

typedef struct __LINK_PART {
	char pcLinkName[STAT_LEN + 1];
	POINT stStart;
	POINT stEnd;
	char cPrev;
	char cNext;
	char cClose;
} LINK_PART, *pLINK_PART;

typedef struct __STATUS {
	LINK_PART pstLinkParts[MAX_PARTS + 1];
	char pppcStats[MAX_SIZE][MAX_SIZE][STAT_LEN + 1];
	char pppcHwalls[MAX_SIZE][MAX_SIZE][STAT_LEN + 1];
	char pppcVwalls[MAX_SIZE][MAX_SIZE][1 + 1];
	char ppcFd1Flags[MAX_SIZE][MAX_SIZE];
} STATUS, *pSTATUS;

typedef struct __DIRECTION {
	char pcDirMark[STAT_LEN + 1];
	char cRowDelta;
	char cColDelta;
} DIRECTION, *pDIRECTION;

typedef struct __NEIGHBOR {
	pDIRECTION pstDir;
	POINT stPoint;
} NEIGHBOR, *pNEIGHBOR;

static DIRECTION gpstDirections[] = {
	{RIGHT_MARK, 0,  1},
	{DOWN_MARK,  1,  0},
	{LEFT_MARK,  0, -1},
	{UP_MARK,   -1,  0},
};

static DIRECTION gpstArounds[] = {
	{ "",  0,  1},
	{ "",  1,  1},
	{ "",  1,  0},
	{ "",  1, -1},
	{ "",  0, -1},
	{ "", -1, -1},
	{ "", -1,  0},
	{ "", -1,  1}
};

static int gpiSplitPatterns[] = {
	9,10,11,17,18,19,25,26,27,
	33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,49,50,51,57,58,59,
	66,68,70,72,73,74,75,76,77,78,82,
	98,100,102,104,105,106,107,108,110,114,122,
	130,132,134,136,137,138,139,140,142,144,145,146,147,148,150,152,153,154,155,156,158,
	160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,182,184,185,186,187,188,190,
	194,196,198,200,201,202,203,204,206,210,
	226,228,230,232,233,234,235,236,238,242,250,
	-1
};

static char gpcSplitPatternTbl[SPLIT_PAT_CNT];
static char gppcZeroExitPoints[MAX_SIZE][MAX_SIZE];

static char gcSize;
static LINK_DEF gpstLinkDefs[MAX_DEFS + 1];

//static char gcSize = 7;
//LINK_DEF gpstLinkDefs[] = {
//	{"1", {{4, 0}, {4, 4}, {-1, -1}}},
//	{"2", {{0, 6}, {3, 2}, {-1, -1}}},
//	{"3", {{1, 2}, {2, 5}, {-1, -1}}},
//	{"4", {{1, 4}, {6, 6}, {-1, -1}}},
//	{"5", {{0, 0}, {6, 0}, {-1, -1}}},
//	{""}
//};

static time_t gtStartTime;
static long giOkCases;
static long giBranchErrCases;
static long giDeadEndCases;
static long giDeadPartitionCases;
static long giSplitLinkCases;
static long giFd1DeadPartitionCases;
static long giMultiSplitCases;

static char read_def(
	const char* pcFileName
);
static void chop(
	char *pcLine
);
static char parse_line(
	char *pcLineBuf,
	const char *pcFileName,
	int iLineCnt
);
static void init_globals();
static char init_status(
	pSTATUS pstStatus
);
static void close_connected_links(
	pSTATUS pstStatus
);
static void answer_gen(
	pSTATUS pstStatus
);

static char check_branch(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char *pcLinkName
);
static char check_partition(
	pSTATUS pstStatus
);
static char fill_partition(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char ppcExitPoints[MAX_SIZE][MAX_SIZE]
);

static char check_forward1(
	pSTATUS pstStatus
);
static char check_forward1_at(
	pSTATUS pstStatus,
	pPOINT pstPoint
);
static void fill_partition_forward1(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char ppcExitPoints[MAX_SIZE][MAX_SIZE]
);

static void open_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char *pcLinkName,
	char *pcMark
);
static void set_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char *pcLinkName,
	char *pcMark
);
static void close_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
);
static void fill_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
);
static char* get_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
);
static char has_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
);

static void set_direction(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	pDIRECTION pstDir
);
static void get_neighbors(
	pPOINT pstPoint,
	pNEIGHBOR pstNeighbors
);

static void close_connected_link(
	pSTATUS pstStatus,
	pLINK_PART pstLinkPart
);
static pLINK_PART get_open_link(
	pSTATUS pstStatus
);

static void set_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
);
static void delete_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
);
static void update_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
);
static char is_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
);

static void get_arounds(
	pPOINT pstPoint,
	pPOINT pstArounds
);
static char has_split_at(
	pSTATUS pstStatus,
	pPOINT pstPoint
);

static void print_progress(
	pSTATUS pstStatus
);
static void print_status(
	pSTATUS pstStatus
);
static void print_grid(
	pSTATUS pstStatus
);
static void print_link(
	pLINK_PART pstLinkPart
);
static void print_links(
	pLINK_PART pstLinkParts
);
static void print_exit(
	char ppcExitPoints[MAX_SIZE][MAX_SIZE]
);

int main(int argc, char **argv) {

	STATUS stStatus;

	if (argc != 2) {
		printf("usage : NumLinkSolver filename");
		exit(0);
	}

	if (read_def(argv[1]) != RET_OK) {
		exit(0);
	}

	init_globals();
	if (init_status(&stStatus) != RET_OK) {
		exit(0);
	}
	close_connected_links(&stStatus);

	print_status(&stStatus);
	DEBUG_DUMP((char *) &stStatus, sizeof(stStatus));

	answer_gen(&stStatus);
}

static char read_def(
	const char* pcFileName
) {

	FILE *pstFile;
	char pcLineBuf[LINE_BUF_LEN + 1];
	int iLineCnt;


	gcSize = -1;
	memset(gpstLinkDefs, '\0', sizeof(gpstLinkDefs));

	pstFile = fopen(pcFileName, "r");
	if (pstFile == NULL) {
		printf("file open failed. file : %s, errno = %d", pcFileName, errno);
		return RET_NG;
	}

	iLineCnt = 0;
	memset(pcLineBuf, '\0', sizeof(pcLineBuf));

	while (fgets(pcLineBuf, LINE_BUF_LEN + 1, pstFile) != NULL) {

		++iLineCnt;
		chop(pcLineBuf);

		if (parse_line(pcLineBuf, pcFileName, iLineCnt) != RET_OK) {
			fclose(pstFile);
			return RET_NG;
		}
	}

	fclose(pstFile);

	return RET_OK;
}

static void chop(
	char *pcLine
) {

	int iLen = strlen(pcLine);
	while (--iLen >= 0) {
		if (!isspace(pcLine[iLen])) {
			break;
		}
		pcLine[iLen] = '\0';
	}
}

static char parse_line(
	char *pcLineBuf,
	const char *pcFileName,
	int iLineCnt
) {

	static pLINK_DEF pstLinkDef = gpstLinkDefs;

	char *pcLinePtr;

	char *pcMethod;

	char *pcSize;
	int iSize;

	char *pcLinkName;
	int iLinkNameLen;
	pPOINT pstPoint;

	char *pcRow;
	char *pcCol;
	int iRow;
	int iCol;

	pLINK_DEF pstLinkDefChk;
	pPOINT pstPointChk;

	if (*pcLineBuf == '#') {
		// コメント行
		return RET_OK;
	}

	pcLinePtr = pcLineBuf;

	_consume_space(pcLinePtr);

	if (*pcLinePtr == '\0') {
		// 空行
		return RET_OK;
	}

	pcMethod = pcLinePtr;

	_get_token(pcLinePtr, ' ');

	if (
		strcmp(pcMethod, "size") != 0
		&& strcmp(pcMethod, "link") != 0
	) {
		_parse_error("%s : 'size' or 'link' required.", pcMethod);
		return RET_NG;
	}

	if (strcmp(pcMethod, "size") == 0) {

		if (*pcLinePtr == '\0') {
			_parse_error("%s : size required.", pcMethod);
			return RET_NG;
		}

		pcSize = pcLinePtr;

		_get_token(pcLinePtr, ' ');

		iSize = atoi(pcSize);
		if (iSize < MIN_SIZE || iSize > MAX_SIZE) {
			_parse_error("%s : size must be between %d and %d.", pcSize, MIN_SIZE, MAX_SIZE);
			return RET_NG;
		}

		gcSize = iSize;

		if (*pcLinePtr != '\0') {
			_parse_error("%s : syntax error.", pcLinePtr);
			return RET_NG;
		}
	}

	if (strcmp(pcMethod, "link") == 0) {

		if (gcSize < 0) {
			_parse_error("size must be specified before link definition.");
			return RET_NG;
		}

		if ((pstLinkDef - gpstLinkDefs) >= MAX_DEFS) {
			_parse_error("link definition count exceeded %d.", MAX_DEFS);
			return RET_NG;
		}

		// 定義がなかったらエラー
		if (*pcLinePtr == '\0') {
			_parse_error("link definition required.");
			return RET_NG;
		}

		// リンク名開始記号がなかったらエラー
		if (*pcLinePtr != '\'') {
			_parse_error("%s : link name must start with '.", pcLinePtr);
			return RET_NG;
		}

		// リンク名の始端をNULL止め
		_consume_delim(pcLinePtr);

		// リンク名の先頭アドレスを取得
		pcLinkName = pcLinePtr;

		_get_number(pcLinePtr);

		// リンク名の終了記号がなかったらエラー
		if (*pcLinePtr != '\'') {
			_parse_error("link name must end with '.");
			return RET_NG;
		}

		// リンク名の終端をNULL止め
		_consume_delim(pcLinePtr);

		// リンク名は1から2バイト
		iLinkNameLen = strlen(pcLinkName);
		if (iLinkNameLen < 1 || iLinkNameLen > LINK_NAME_LEN) {
			_parse_error("%s : link name length must be between 1 and %d.", pcLinkName, LINK_NAME_LEN);
			return RET_NG;
		}

		for (pstLinkDefChk = gpstLinkDefs; pstLinkDefChk < pstLinkDef; pstLinkDefChk++) {
			if (atoi(pcLinkName) == atoi(pstLinkDefChk->pcLinkName)) {
				_parse_error("%s : link name already exists.", pcLinkName);
				return RET_NG;
			}
		}

		strcpy(pstLinkDef->pcLinkName, pcLinkName);
		pstPoint = pstLinkDef->pstPoints;

		do {

			// カンマがなかったらエラー
			if (*pcLinePtr != ',') {
				_parse_error("%s : missing delimiter.", pcLinePtr);
				return RET_NG;
			}

			if ((pstPoint - pstLinkDef->pstPoints) >= MAX_POINTS) {
				_parse_error("link points count exceeded %d.", MAX_POINTS);
				return RET_NG;
			}

			// カンマをNULL止め
			_consume_delim(pcLinePtr);

			// ポイントの開始括弧がなかったらエラー
			if (*pcLinePtr != '[') {
				_parse_error("%s : link point must start with '['.", pcLinePtr);
				return RET_NG;
			}

			// ポイントの開始括弧をNULL止め
			_consume_delim(pcLinePtr);

			// 行番号がなかったらエラー
			if (!isdigit(*pcLinePtr)) {
				_parse_error("%s : link point(row) required.", pcLinePtr);
				return RET_NG;
			}

			// 行番号の先頭アドレスを取得
			pcRow = pcLinePtr;

			// 行番号の末尾までポインタを進める
			_get_number(pcLinePtr);

			// カンマがなかったらエラー
			if (*pcLinePtr != ',') {
				_parse_error("%s : missing delimiter.", pcLinePtr);
				return RET_NG;
			}

			// カンマをNULL止め
			_consume_delim(pcLinePtr);

			// 列番号がなかったらエラー
			if (!isdigit(*pcLinePtr)) {
				_parse_error("%s : link point(column) required.", pcLinePtr);
				return RET_NG;
			}

			// 列番号の先頭アドレスを取得
			pcCol = pcLinePtr;

			// 列番号の末尾までポインタを進める
			_get_number(pcLinePtr);

			// ポイントの終了括弧がなかったらエラー
			if (*pcLinePtr != ']') {
				_parse_error("%s : link point must end with ']'.", pcLinePtr);
				return RET_NG;
			}

			// ポイントの終了括弧をNULL止め
			_consume_delim(pcLinePtr);

			iRow = atoi(pcRow);
			if (iRow < 0 || iRow >= gcSize) {
				_parse_error("%s : row number must be between 0 and %d.", pcRow, gcSize - 1);
				return RET_NG;
			}
			pstPoint->cRow = iRow;

			iCol = atoi(pcCol);
			if (iCol < 0 || iCol >= gcSize) {
				_parse_error("%s : column number must be between 0 and %d.", pcCol, gcSize - 1);
				return RET_NG;
			}
			pstPoint->cCol = iCol;

			for (pstLinkDefChk = gpstLinkDefs; pstLinkDefChk <= pstLinkDef; pstLinkDefChk++) {
				for (pstPointChk = pstLinkDefChk->pstPoints; HAS_POINT(pstPointChk) && pstPointChk < pstPoint; pstPointChk++) {
					if (memcmp(pstPoint, pstPointChk, sizeof(POINT)) == 0) {
						_parse_error("point [%d,%d] already exists.", iRow, iCol);
						return RET_NG;
					}
				}
			}
			pstPoint++;

		} while (*pcLinePtr != '\0');

		if ((pstPoint - pstLinkDef->pstPoints) < MIN_POINTS) {
			_parse_error("link definition must have at least %d points.", MIN_POINTS);
			return RET_NG;
		}

		pstPoint->cRow = -1;
		pstPoint->cCol = -1;
		pstLinkDef++;

	}

	return RET_OK;
}

static void init_globals() {

	int *piSplitPattern;

	memset(gpcSplitPatternTbl, '\0', sizeof(gpcSplitPatternTbl));
	for (piSplitPattern =gpiSplitPatterns; *piSplitPattern >= 0; piSplitPattern++) {
		gpcSplitPatternTbl[*piSplitPattern] = FLG_ON;
	}

	memset(gppcZeroExitPoints, '\0', sizeof(gppcZeroExitPoints));

	time(&gtStartTime);
	giOkCases = 0;
	giBranchErrCases = 0;
	giDeadEndCases = 0;
	giDeadPartitionCases = 0;
	giSplitLinkCases = 0;
	giFd1DeadPartitionCases = 0;
	giMultiSplitCases = 0;

}

static char init_status(
	pSTATUS pstStatus
) {

	pLINK_DEF pstLinkDef;
	pLINK_PART pstLinkPart;
	pLINK_PART pstPrevLink;
	pPOINT pstFrom;
	pPOINT pstTo;

	char cRow;
	char cCol;

	memset(pstStatus, '\0', sizeof(STATUS));
	pstLinkPart = pstStatus->pstLinkParts;

	for (pstLinkDef = gpstLinkDefs; HAS_LINK(pstLinkDef); pstLinkDef++) {

		pstPrevLink = NULL;

		for (pstFrom = pstLinkDef->pstPoints; HAS_POINT(pstFrom); pstFrom++) {

			pstTo = pstFrom + 1;

			if (pstTo->cRow >= 0) {

				if ((pstLinkPart - pstStatus->pstLinkParts) >= MAX_PARTS) {
					printf("error : link parts count exceeded %d", MAX_PARTS);
					return RET_NG;
				}

				memcpy(pstLinkPart->pcLinkName, pstLinkDef->pcLinkName, STAT_LEN);
				memcpy(&(pstLinkPart->stStart), pstFrom, sizeof(POINT));
				memcpy(&(pstLinkPart->stEnd), pstTo, sizeof(POINT));

				if (pstPrevLink == NULL) {
					pstLinkPart->cPrev = -1;
					open_stat(pstStatus, pstFrom, pstLinkDef->pcLinkName, START_MARK);
				} else {
					pstPrevLink->cNext = pstLinkPart - pstStatus->pstLinkParts;
					pstLinkPart->cPrev = pstPrevLink - pstStatus->pstLinkParts;
					open_stat(pstStatus, pstFrom, pstLinkDef->pcLinkName, MID_MARK);
				}

				pstPrevLink = pstLinkPart;
				pstLinkPart++;

			} else {
				pstPrevLink->cNext = -1;
				open_stat(pstStatus, pstFrom, pstLinkDef->pcLinkName, END_MARK);
			}
		}
	}

	for (cRow = 0; cRow < gcSize; cRow++) {
		for (cCol = 0; cCol < gcSize; cCol++) {
			strcpy(pstStatus->pppcHwalls[cRow][cCol], H_WALL);
			strcpy(pstStatus->pppcVwalls[cRow][cCol], V_WALL);
		}
	}

	return RET_OK;
}

static void close_connected_links(
	pSTATUS pstStatus
) {

	pLINK_PART pstLinkPart;

	for (pstLinkPart = pstStatus->pstLinkParts; HAS_LINK(pstLinkPart); pstLinkPart++) {
		close_connected_link(pstStatus, pstLinkPart);
	}
}

static void answer_gen(
	pSTATUS pstStatus
) {
	pLINK_PART pstLinkPart;
	POINT stPoint;

	NEIGHBOR pstNeighbors[NEIGHBOR_CNT + 1];
	pNEIGHBOR pstNeighbor;
	pDIRECTION pstDir;

	STATUS stStatus2;
	POINT stPoint2;
	pSTATUS pstStatus2;
	pLINK_PART pstLinkPart2;

	pstLinkPart = get_open_link(pstStatus);

	if (pstLinkPart == NULL) {
		DEBUG_PRINTF("\n----- !!!!!solved!!!!! -----");
		print_status(pstStatus);
		exit(0);
	}

	if (check_partition(pstStatus) != RET_OK) {
		return;
	}

	if (check_forward1(pstStatus) != RET_OK) {
		return;
	}

	print_progress(pstStatus);

	stPoint = pstLinkPart->stStart;
	get_neighbors(&stPoint, pstNeighbors);

	for (pstNeighbor = pstNeighbors; HAS_NEIGHBOR(pstNeighbor); pstNeighbor++) {

		stPoint2 = pstNeighbor->stPoint;
		pstDir = pstNeighbor->pstDir;

		if (has_stat(pstStatus, &stPoint2) == RET_OK) {
			continue;
		}

		if (check_branch(pstStatus, &stPoint2, pstLinkPart->pcLinkName) != RET_OK) {
			continue;
		}

		memcpy(&stStatus2, pstStatus, sizeof(STATUS));
		pstLinkPart2 = get_open_link(&stStatus2);

		close_stat(&stStatus2, &stPoint);
		set_direction(&stStatus2, &stPoint, pstDir);
		open_stat(&stStatus2, &stPoint2, pstLinkPart2->pcLinkName, NULL);

		pstLinkPart2->stStart = stPoint2;
		close_connected_link(&stStatus2, pstLinkPart2);

		answer_gen(&stStatus2);
	}

}

static char check_branch(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char *pcLinkName
) {

	char pcClosedStat[STAT_LEN + 1];

	NEIGHBOR pstNeighbors[NEIGHBOR_CNT + 1];
	pNEIGHBOR pstNeighbor;
	char *pcStat;

	sprintf(pcClosedStat, "%2s%1s", pcLinkName, CLOSE_MARK);

	get_neighbors(pstPoint, pstNeighbors);
	for (pstNeighbor = pstNeighbors; HAS_NEIGHBOR(pstNeighbor); pstNeighbor++) {

		pcStat = get_stat(pstStatus, &(pstNeighbor->stPoint));

		if (strcmp(pcStat, pcClosedStat) == 0) {
			giBranchErrCases++;
			DEBUG_PRINTF("\n----- branch of '%s' at [%d, %d] -----\n", pcLinkName, pstPoint->cRow, pstPoint->cCol);
			DEBUG_PRINT_GRID(pstStatus);
			return RET_NG;
		}
	}

	return RET_OK;
}

static char check_partition(
	pSTATUS pstStatus
) {

	STATUS stStatus2;
	POINT stPoint;
	char ppcExitPoints[MAX_SIZE][MAX_SIZE];
	char cPartActive;
	pLINK_PART pstLinkPart;

	memcpy(&stStatus2, pstStatus, sizeof(STATUS));

	for (stPoint.cRow = 0; stPoint.cRow < gcSize; stPoint.cRow++) {
		for (stPoint.cCol = 0; stPoint.cCol < gcSize; stPoint.cCol++) {

			if (has_stat(&stStatus2, &stPoint) == RET_OK) {
				continue;
			}

			memset(ppcExitPoints, '\0', sizeof(ppcExitPoints));
			if (fill_partition(&stStatus2, &stPoint, ppcExitPoints) != RET_OK) {
				return RET_NG;
			}

			cPartActive = FLG_OFF;

			for (pstLinkPart = pstStatus->pstLinkParts; HAS_LINK(pstLinkPart); pstLinkPart++) {
				if (pstLinkPart->cClose == FLG_ON) {
					continue;
				}
				if (ppcExitPoints[pstLinkPart->stStart.cRow][pstLinkPart->stStart.cCol] != FLG_ON) {
					continue;
				}
				if (ppcExitPoints[pstLinkPart->stEnd.cRow][pstLinkPart->stEnd.cCol] != FLG_ON) {
					continue;
				}
				cPartActive = FLG_ON;
				stStatus2.pstLinkParts[pstLinkPart - pstStatus->pstLinkParts].cClose = FLG_ON;

			}

//			DEBUG_PRINTF("  fill : [%d, %d], exit : ", stPoint.cRow, stPoint.cCol);
//			DEBUG_PRINT_EXIT(ppcExitPoints);
//			DEBUG_PRINTF(" active : %d\n", cPartActive);

			// リンクが引けないシマ
			if (cPartActive != FLG_ON) {
				giDeadPartitionCases++;
				DEBUG_PRINTF("\n----- dead partition at [%d, %d] -----\n", stPoint.cRow, stPoint.cCol);
				DEBUG_PRINT_GRID(&stStatus2);
				return RET_NG;
			}
		}
	}

	// 到達不可能なリンクがある場合
	pstLinkPart = get_open_link(&stStatus2);
	if (pstLinkPart != NULL) {
		giSplitLinkCases++;
		DEBUG_PRINTF("\n----- split link ");
		DEBUG_PRINT_LINK(pstLinkPart);
		DEBUG_PRINTF(" -----\n");
		DEBUG_PRINT_GRID(&stStatus2);
		return RET_NG;
	}

	return RET_OK;
}

static char fill_partition(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char ppcExitPoints[MAX_SIZE][MAX_SIZE]
) {

	NEIGHBOR pstNeighbors[NEIGHBOR_CNT + 1];
	pNEIGHBOR pstNeighbor;
	char cFreeCnt;
	char *pcStat;

	cFreeCnt = 0;
	get_neighbors(pstPoint, pstNeighbors);
	for (pstNeighbor = pstNeighbors; HAS_NEIGHBOR(pstNeighbor); pstNeighbor++) {

		pcStat = get_stat(pstStatus, &(pstNeighbor->stPoint));

		if (strcmp(pcStat + 2, CLOSE_MARK) == 0) {
			continue;
		}

		cFreeCnt++;

		if (atoi(pcStat) > 0) {
			ppcExitPoints[pstNeighbor->stPoint.cRow][pstNeighbor->stPoint.cCol] = FLG_ON;
		}
	}

	//袋小路になってる
	if (cFreeCnt <= 1) {
		giDeadEndCases++;
		DEBUG_PRINTF("\n----- dead end at [%d, %d] -----\n",  pstPoint->cRow, pstPoint->cCol);
		DEBUG_PRINT_GRID(pstStatus);
		return RET_NG;
	}

	fill_stat(pstStatus, pstPoint);

	for (pstNeighbor = pstNeighbors; HAS_NEIGHBOR(pstNeighbor); pstNeighbor++) {
		if (has_stat(pstStatus, &(pstNeighbor->stPoint)) == RET_OK) {
			continue;
		}

		if (fill_partition(pstStatus, &(pstNeighbor->stPoint), ppcExitPoints) != RET_OK) {
			return RET_NG;
		}
	}

	return RET_OK;
}

static char check_forward1(
	pSTATUS pstStatus
) {
	char *pcFd1Flag;
	POINT stPoint;

	for (stPoint.cRow = 0; stPoint.cRow < gcSize; stPoint.cRow++) {
		for (stPoint.cCol = 0; stPoint.cCol < gcSize; stPoint.cCol++) {
			if (is_fd1_point(pstStatus, &stPoint) != RET_OK) {
				continue;
			}
			if (check_forward1_at(pstStatus, &stPoint) != RET_OK) {
				return RET_NG;
			}
		}
	}

	return RET_OK;
}

static char check_forward1_at(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {

	STATUS stStatus2;
	POINT stPoint;
	char ppcExitPoints[MAX_SIZE][MAX_SIZE];
	pLINK_PART pstLinkPart;
	char cActiveCnt;

	memcpy(&stStatus2, pstStatus, sizeof(STATUS));
	set_stat(&stStatus2, pstPoint, "0", CLOSE_MARK);

	for (stPoint.cRow = 0; stPoint.cRow < gcSize; stPoint.cRow++) {
		for (stPoint.cCol = 0; stPoint.cCol < gcSize; stPoint.cCol++) {

			if (has_stat(&stStatus2, &stPoint) == RET_OK) {
				continue;
			}

			memset(ppcExitPoints, '\0', sizeof(ppcExitPoints));
			fill_partition_forward1(&stStatus2, &stPoint, ppcExitPoints);

//			DEBUG_PRINTF("  forward : [%d, %d], exit : ", stPoint.cRow, stPoint.cCol);
//			DEBUG_PRINT_EXIT(ppcExitPoints);
//			DEBUG_PRINTF("\n");

			if (memcmp(ppcExitPoints, gppcZeroExitPoints, sizeof(ppcExitPoints)) == 0) {
				giFd1DeadPartitionCases++
				DEBUG_PRINTF(
					"\n----- dead partition by [%d, %d] at [%d, %d] -----\n",
					pstPoint->cRow, pstPoint->cCol, stPoint.cRow, stPoint.cCol
				);
				DEBUG_PRINT_GRID(&stStatus2);
				return RET_NG;
			}

			for (pstLinkPart = pstStatus->pstLinkParts; HAS_LINK(pstLinkPart); pstLinkPart++) {
				if (pstLinkPart->cClose == FLG_ON) {
					continue;
				}
				if (ppcExitPoints[pstLinkPart->stStart.cRow][pstLinkPart->stStart.cCol] != FLG_ON) {
					continue;
				}
				if (ppcExitPoints[pstLinkPart->stEnd.cRow][pstLinkPart->stEnd.cCol] != FLG_ON) {
					continue;
				}
				stStatus2.pstLinkParts[pstLinkPart - pstStatus->pstLinkParts].cClose = FLG_ON;
			}
		}
	}

	cActiveCnt = 0;
	for (pstLinkPart = stStatus2.pstLinkParts; HAS_LINK(pstLinkPart); pstLinkPart++) {
		if (pstLinkPart->cClose == FLG_ON) {
			continue;
		}
		cActiveCnt++;
		if (cActiveCnt > 1) {
			giMultiSplitCases++
			DEBUG_PRINTF("\n----- multiple split at [%d, %d] for ", pstPoint->cRow, pstPoint->cCol);
			DEBUG_PRINT_LINKS(stStatus2.pstLinkParts);
			DEBUG_PRINTF(" -----\n");
			DEBUG_PRINT_GRID(&stStatus2);
			return RET_NG;
		}
	}

	return RET_OK;
}

static void fill_partition_forward1(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char ppcExitPoints[MAX_SIZE][MAX_SIZE]
) {

	NEIGHBOR pstNeighbors[NEIGHBOR_CNT + 1];
	pNEIGHBOR pstNeighbor;
	char *pcStat;

	fill_stat(pstStatus, pstPoint);

	get_neighbors(pstPoint, pstNeighbors);
	for (pstNeighbor = pstNeighbors; HAS_NEIGHBOR(pstNeighbor); pstNeighbor++) {

		pcStat = get_stat(pstStatus, &(pstNeighbor->stPoint));

		if (strcmp(pcStat + 2, CLOSE_MARK) == 0) {
			continue;
		}

		if (atoi(pcStat) > 0) {
			ppcExitPoints[pstNeighbor->stPoint.cRow][pstNeighbor->stPoint.cCol] = FLG_ON;
		}

		if (has_stat(pstStatus, &(pstNeighbor->stPoint)) == RET_OK) {
			continue;
		}

		fill_partition_forward1(pstStatus, &(pstNeighbor->stPoint), ppcExitPoints);
	}
}

static void open_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char *pcLinkName,
	char *pcMark
) {

	set_stat(pstStatus, pstPoint, pcLinkName, pcMark);
	update_fd1_point(pstStatus, pstPoint);

}

static void set_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	char *pcLinkName,
	char *pcMark
) {

	char *pcDest = pstStatus->pppcStats[pstPoint->cRow][pstPoint->cCol];
	if (pcMark == NULL) {
		sprintf(pcDest, "%2s", pcLinkName);
	} else {
		sprintf(pcDest, "%2s%1s", pcLinkName, pcMark);
	}
}

static void close_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {
	char *pcDest = pstStatus->pppcStats[pstPoint->cRow][pstPoint->cCol];
	strcpy(pcDest + 2, CLOSE_MARK);
}

static void fill_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {
	char *pcDest = pstStatus->pppcStats[pstPoint->cRow][pstPoint->cCol];
	strcpy(pcDest, FILLER);
}

static char* get_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {
	return pstStatus->pppcStats[pstPoint->cRow][pstPoint->cCol];
}

static char has_stat(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {

	if (*get_stat(pstStatus, pstPoint) == '\0') {
		return RET_NG;
	}

	return RET_OK;
}

static void set_direction(
	pSTATUS pstStatus,
	pPOINT pstPoint,
	pDIRECTION pstDir
) {
	char cRow = pstPoint->cRow;
	char cCol = pstPoint->cCol;
	char cDir =  pstDir - gpstDirections;
	char *pcDest;

	switch (cDir) {
	case DIR_UP:
		pcDest = pstStatus->pppcHwalls[cRow][cCol];
		break;
	case DIR_DOWN:
		pcDest = pstStatus->pppcHwalls[cRow + 1][cCol];
		break;
	case DIR_LEFT:
		pcDest = pstStatus->pppcVwalls[cRow][cCol];
		break;
	case DIR_RIGHT:
		pcDest = pstStatus->pppcVwalls[cRow][cCol + 1];
		break;
	default:
		return;
		break;
	}

	strcpy(pcDest, pstDir->pcDirMark);
}

static void get_neighbors(
	pPOINT pstPoint,
	pNEIGHBOR pstNeighbors
) {

	pDIRECTION pstDirection;
	char c;
	char cRow;
	char cCol;

	memset(pstNeighbors, '\0', sizeof(NEIGHBOR) * (NEIGHBOR_CNT + 1));

	for (pstDirection = gpstDirections, c = 0; c < NEIGHBOR_CNT; pstDirection++, c++) {

		cRow= pstPoint->cRow + pstDirection->cRowDelta;
		if (cRow < 0 || cRow >= gcSize) {
			continue;
		}

		cCol = pstPoint->cCol + pstDirection->cColDelta;
		if (cCol < 0 || cCol >= gcSize) {
			continue;
		}

		pstNeighbors->pstDir = pstDirection;
		pstNeighbors->stPoint.cRow = cRow;
		pstNeighbors->stPoint.cCol = cCol;
		pstNeighbors++;
	}

}

static void close_connected_link(
	pSTATUS pstStatus,
	pLINK_PART pstLinkPart
) {

	POINT stFrom = pstLinkPart->stStart;
	POINT stTo = pstLinkPart->stEnd;
	pDIRECTION pstDirection;
	char c;
	char cPrev;
	char cNext;

	for (pstDirection = gpstDirections, c = 0; c < NEIGHBOR_CNT; pstDirection++, c++) {
		if (
			(stTo.cRow - stFrom.cRow == pstDirection->cRowDelta)
			&& (stTo.cCol - stFrom.cCol == pstDirection->cColDelta)
		) {
			break;
		}
	}

	if (c >= NEIGHBOR_CNT) {
		return;
	}

	cPrev = pstLinkPart->cPrev;
	if (cPrev < 0) {
		close_stat(pstStatus, &stFrom);
	} else if (pstStatus->pstLinkParts[cPrev].cClose == FLG_ON) {
		close_stat(pstStatus, &stFrom);
	}
	set_direction(pstStatus, &stFrom, pstDirection);
	cNext = pstLinkPart->cNext;
	if (cNext < 0) {
		close_stat(pstStatus, &stTo);
	} else if (pstStatus->pstLinkParts[cNext].cClose == FLG_ON) {
		close_stat(pstStatus, &stTo);
	}
	pstLinkPart->cClose = FLG_ON;

	DEBUG_PRINTF("\n ----- link ");
	DEBUG_PRINT_LINK(pstLinkPart);
	DEBUG_PRINTF(" closed. -----\n");
	DEBUG_PRINT_GRID(pstStatus);

}

static pLINK_PART get_open_link(
	pSTATUS pstStatus
) {
	pLINK_PART pstLinkPart;

	for (pstLinkPart = pstStatus->pstLinkParts; HAS_LINK(pstLinkPart); pstLinkPart++) {
		if (pstLinkPart->cClose == FLG_OFF) {
			return pstLinkPart;
		}
	}

	return NULL;
}

static void set_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {
	pstStatus->ppcFd1Flags[pstPoint->cRow][pstPoint->cCol] = FLG_ON;
}

static void delete_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {
	pstStatus->ppcFd1Flags[pstPoint->cRow][pstPoint->cCol] = FLG_OFF;
}

static void update_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {

	POINT pstArounds[AROUND_CNT + 1];
	pPOINT pstAround;

	delete_fd1_point(pstStatus, pstPoint);

	get_arounds(pstPoint, pstArounds);
	for (pstAround = pstArounds; HAS_POINT(pstAround); pstAround++) {

		if (has_stat(pstStatus, pstAround) == RET_OK) {
			continue;
		}

		if (has_split_at(pstStatus, pstAround) != RET_OK) {
			delete_fd1_point(pstStatus, pstAround);
			continue;
		}

		set_fd1_point(pstStatus, pstAround);
	}

}

static char is_fd1_point(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {
	if (pstStatus->ppcFd1Flags[pstPoint->cRow][pstPoint->cCol] == FLG_ON) {
		return RET_OK;
	} else {
		return RET_NG;
	}
}

static void get_arounds(
	pPOINT pstPoint,
	pPOINT pstArounds
) {
	pDIRECTION pstDirection;
	char c;
	char cRow;
	char cCol;

	memset(pstArounds, '\0', sizeof(POINT) * (AROUND_CNT + 1));

	for (pstDirection = gpstArounds, c = 0; c < AROUND_CNT; pstDirection++, c++) {

		cRow= pstPoint->cRow + pstDirection->cRowDelta;
		if (cRow < 0 || cRow >= gcSize) {
			continue;
		}

		cCol = pstPoint->cCol + pstDirection->cColDelta;
		if (cCol < 0 || cCol >= gcSize) {
			continue;
		}

		pstArounds->cRow = cRow;
		pstArounds->cCol = cCol;
		pstArounds++;
	}

	pstArounds->cRow = -1;

}

static char has_split_at(
	pSTATUS pstStatus,
	pPOINT pstPoint
) {

	pDIRECTION pstDirection;
	char c;
	char cRow;
	char cCol;
	POINT stAround;
	int iAroundPat;
	int iAroundFlg;

	iAroundPat = 0;
	for (pstDirection = gpstArounds, c = 0; c < AROUND_CNT; pstDirection++, c++) {

		iAroundFlg = 1 << c;

		cRow = pstPoint->cRow + pstDirection->cRowDelta;
		if (cRow < 0 || cRow >= gcSize) {
			iAroundPat |= iAroundFlg;
			continue;
		}

		cCol = pstPoint->cCol + pstDirection->cColDelta;
		if (cCol < 0 || cCol >= gcSize) {
			iAroundPat |= iAroundFlg;
			continue;
		}

		stAround.cRow = cRow;
		stAround.cCol = cCol;
		if (has_stat(pstStatus, &stAround) == RET_OK) {
			iAroundPat |= iAroundFlg;
		}
	}

	if (gpcSplitPatternTbl[iAroundPat] == FLG_ON) {
		return RET_OK;
	} else {
		return RET_NG;
	}
}

static void print_grid(
	pSTATUS pstStatus
) {

	POINT stPoint;

	for (stPoint.cRow = 0; stPoint.cRow < gcSize; stPoint.cRow++) {
		if (stPoint.cRow > 0) {
			for (stPoint.cCol = 0; stPoint.cCol < gcSize; stPoint.cCol++) {
				if (stPoint.cCol > 0) {
					printf("+");
				}
				printf("%3s", pstStatus->pppcHwalls[stPoint.cRow][stPoint.cCol]);
			}
			printf("\n");
		}
		for (stPoint.cCol = 0; stPoint.cCol < gcSize; stPoint.cCol++) {
			if (stPoint.cCol > 0) {
				printf("%1s", pstStatus->pppcVwalls[stPoint.cRow][stPoint.cCol]);
			}
			if (has_stat(pstStatus, &stPoint) == RET_OK) {
				printf("%-3s", get_stat(pstStatus, &stPoint));
			} else if (is_fd1_point(pstStatus, &stPoint) == RET_OK) {
				printf(FD1_MARK);
			} else {
				printf("   ");
			}
		}
		printf("\n");
	}
}

static void print_status(
	pSTATUS pstStatus
) {

	time_t tNowTime;
	int iElapsed;
	int iElapsed2;
	int iHours;
	int iMinutes;
	int iSeconds;

	time(&tNowTime);
	iElapsed = (int) difftime(tNowTime, gtStartTime);

	iElapsed2 = iElapsed / 60;
	iHours = iElapsed2 / 60;
	iMinutes = iElapsed2 % 60;
	iSeconds = iElapsed % 60;

	printf(
    	"\ntm:%02d:%02d:%02d, br:%d, de:%d, dp:%d, sl:%d, fdp:%d, msl:%d, ok:%d\n",
    	iHours,
    	iMinutes,
    	iSeconds,
        giBranchErrCases,
        giDeadEndCases,
        giDeadPartitionCases,
        giSplitLinkCases,
        giFd1DeadPartitionCases,
        giMultiSplitCases,
        giOkCases
    );

    print_grid(pstStatus);

}

static void print_progress(
	pSTATUS pstStatus
) {
	if (BREAK > 0) {
		printf(".");
		giOkCases++;
		if (giOkCases % BREAK == 0) {
			print_status(pstStatus);
		}
		fflush(stdout);
	}
}

static void print_link(
	pLINK_PART pstLinkPart
) {
	printf(
		"{'%s':[%d, %d]->[%d, %d]}",
		pstLinkPart->pcLinkName,
		pstLinkPart->stStart.cRow,
		pstLinkPart->stStart.cCol,
		pstLinkPart->stEnd.cRow,
		pstLinkPart->stEnd.cCol
	);
}

static void print_links(
	pLINK_PART pstLinkParts
) {

	pLINK_PART pstLinkPart;

	for (pstLinkPart = pstLinkParts; HAS_LINK(pstLinkPart); pstLinkPart++) {
		if (pstLinkPart->cClose == FLG_OFF) {
			print_link(pstLinkPart);
			printf(", ");
		}
	}
}

static void print_exit(
	char ppcExitPoints[MAX_SIZE][MAX_SIZE]
) {
	char cRow;
	char cCol;

	for (cRow = 0; cRow < gcSize; cRow++) {
		for (cCol = 0; cCol < gcSize; cCol++) {
			if (ppcExitPoints[cRow][cCol] != FLG_ON) {
				continue;
			}
			printf("[%d, %d], ", cRow, cCol);
		}
	}
}
